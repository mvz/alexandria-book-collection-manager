# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "monitor"
require "alexandria/scanners/cue_cat"
require "alexandria/scanners/keyboard"

require "alexandria/ui/builder_base"
require "alexandria/ui/barcode_animation"
require "alexandria/ui/error_dialog"
require "alexandria/ui/sound"

module Alexandria
  module UI
    # assists in turning on progress bar when searching
    # and turning it off when all search threads have completed...
    class SearchThreadCounter < Monitor
      attr_reader :count

      def initialize
        @count = 0
        super
      end

      def new_search
        synchronize do
          @count += 1
        end
      end

      def end_search
        synchronize do
          @count -= 1 unless @count.zero?
        end
      end
    end

    class AcquireDialog < BuilderBase
      include GetText
      include Logging
      extend GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize(parent, selected_library = nil, &block)
        super("acquire_dialog__builder.glade", widget_names)
        @acquire_dialog.transient_for = @parent = parent
        @block = block

        libraries = LibraryCollection.instance.all_regular_libraries
        selected_library = libraries.first if selected_library.is_a?(SmartLibrary)
        @combo_libraries.populate_with_libraries(libraries,
                                                 selected_library)

        @add_button.sensitive = false
        @prefs = Alexandria::Preferences.instance
        setup_scanner_area
        init_treeview
        @book_results = {}

        @search_thread_counter = SearchThreadCounter.new
        @search_threads_running = @search_thread_counter.new_cond
      end

      def show
        @acquire_dialog.show
      end

      def widget_names
        [:acquire_dialog, :add_button, :barcodes_treeview, :barcode_label,
         :scan_area, :scan_frame, :combo_libraries]
      end

      def book_in_library(isbn10, library)
        isbn13 = Library.canonicalise_ean(isbn10)
        match = library.find do |book|
          (book.isbn == isbn10 || book.isbn == isbn13)
        end
        !match.nil?
      rescue StandardError
        log.warn { "Failed to check for book #{isbn10} in library #{library}" }
        true
      end

      def on_add
        model = @barcodes_treeview.model

        libraries = LibraryCollection.instance.all_libraries
        library, is_new_library =
          @combo_libraries.selection_from_libraries(libraries)

        # NOTE: at this stage, the ISBN is 10-digit...
        #

        selection = @barcodes_treeview.selection
        isbns = []
        isbn_duplicates = []

        adding_a_selection = false

        if selection.count_selected_rows > 0

          adding_a_selection = true

          model.freeze_notify do
            # capture isbns
            selection.selected_each do |_mod, _path, iter|
              isbn = iter[0]
              if book_in_library(isbn, library)
                isbn_duplicates << isbn
              elsif isbns.include? isbn
                log.info { "detected duplicate in scanned list #{isbn}" }
                isbn_duplicates << isbn
              else
                isbns << isbn
              end
            end

            # try it this way... works because of persistent iters
            row_iters = []
            selection.selected_rows.each do |path|
              iter = model.get_iter(path)
              isbn = iter[0]
              if book_in_library(isbn, library)
                log.debug { "#{isbn} is a duplicate" }
              elsif !@book_results.key?(isbn) # HAX
                log.debug { "no book found for #{isbn}, not adding" }

                # good enough for now
              else
                log.debug { "scheduling #{isbn} for removal from list" }
                row_iters << iter
              end
            end
            row_iters.each do |iter|
              log.debug { "removing iter #{iter[0]}" }
              model.remove(iter)
            end
          end
        else
          model.freeze_notify do
            # capture isbns
            row_iters = []
            model.each do |_mod, _path, iter|
              isbn = iter[0]
              if !@book_results.key?(isbn)
                log.debug { "no book found for #{isbn}, not adding" }
                adding_a_selection = true
              elsif book_in_library(isbn, library)
                log.info { "#{isbn} is a duplicate" }
                isbn_duplicates << isbn
              elsif isbns.include? isbn
                log.info { "detected duplicate in scanned list #{isbn}" }
                isbn_duplicates << isbn
              else
                log.info { "scheduling #{isbn} for removal from list" }
                isbns << isbn
                row_iters << iter
              end
            end
            # remove list items
            if isbn_duplicates.empty? && !adding_a_selection
              model.clear # TODO: unless!!!
              row_iters.clear
            else
              row_iters.each do |iter|
                log.debug { "removing iter #{iter[0]}" }
                model.remove(iter)
              end
            end
          end
        end

        books = []

        isbns.each do |isbn|
          log.debug { "Adding #{isbn}" }
          result = @book_results[isbn]

          if result.nil?
            # used to crash if book was not found in online lookup!
            adding_a_selection = true
            # ISBN not found, so keep it in the list
            # TODO (for 0.6.5) should offer to add this book manually
          else

            book = result[0]
            cover_uri = result[1]

            library.save_cover(book, cover_uri) unless cover_uri.nil?
            books << book
            library << book
            library.save(book)
          end
        end

        if isbn_duplicates.empty?
          @acquire_dialog.destroy unless adding_a_selection
        else
          message = n_("There was %d duplicate",
                       "There were %d duplicates",
                       isbn_duplicates.size) % isbn_duplicates.size
          title = n_("Couldn't add this book",
                     "Couldn't add these books",
                     isbn_duplicates.size)
          ErrorDialog.new(@acquire_dialog, title, message).display
        end

        @block.call(books, library, is_new_library)
      end

      def on_cancel
        @acquire_dialog.destroy
      end

      def on_help; end

      def read_barcode_scan
        @animation.start
        play_sound("scanning") if @test_scan
        log.debug { "reading scanner data #{@scanner_buffer}" }
        barcode_text = nil
        isbn = nil
        begin
          barcode_text = @scanner.decode(@scanner_buffer)
          log.debug { "got barcode text #{barcode_text}" }
          isbn = Library.canonicalise_isbn(barcode_text)
          # TODO: : use an AppFacade
          # isbn =  LookupBook.get_isbn(barcode_text)
        rescue StandardError => ex
          log.error { "Bad scan:  #{@scanner_buffer} #{ex}" }
        ensure
          @scanner_buffer = ""
        end
        if isbn
          log.debug { "Got ISBN #{isbn}" }
          play_sound("good_scan")

          @barcodes_treeview.model.freeze_notify do
            iter = @barcodes_treeview.model.append
            iter[0] = isbn
            iter[1] = Icons::BOOK
            iter[2] = ""
          end
          lookup_book(isbn)
        else
          log.debug { "was not an ISBN barcode" }
          play_sound("bad_scan")
        end
      end

      # begin copy-n-paste from new_book_dialog

      def notify_start_add_by_isbn
        GLib::Idle.add do
          main_progress_bar = MainApp.instance.appbar.children.first
          main_progress_bar.visible = true
          @progress_pulsing = GLib::Timeout.add(100) do
            if @destroyed
              @progress_pulsing = nil
              false
            else
              main_progress_bar.pulse
              true
            end
          end
          false
        end
      end

      def notify_end_add_by_isbn
        GLib::Idle.add do
          MainApp.instance.appbar.children.first.visible = false
          GLib::Source.remove(@progress_pulsing) if @progress_pulsing
          false
        end
      end

      def update(status, provider)
        GLib::Idle.add do
          messages = {
            searching: _("Searching Provider '%s'..."),
            error: _("Error while Searching Provider '%s'"),
            not_found: _("Not Found at Provider '%s'"),
            found: _("Found at Provider '%s'")
          }
          message = messages[status] % provider
          log.debug { "update message : #{message}" }
          MainApp.instance.ui_manager.set_status_label(message)
          false
        end
      end

      # end copy-n-paste

      private

      def start_search
        @search_thread_counter.synchronize do
          first_search = @search_thread_counter.count.zero?

          @search_thread_counter.new_search

          if first_search
            @progress_bar_thread = Thread.new do
              notify_start_add_by_isbn
              Alexandria::BookProviders.instance.add_observer(self)
              @search_thread_counter.synchronize do
                @search_threads_running.wait_while do
                  @search_thread_counter.count > 0
                end
              end
              notify_end_add_by_isbn
              Alexandria::BookProviders.instance.add_observer(self)
            end
          end
        end
      end

      def stop_search
        @search_thread_counter.synchronize do
          @search_thread_counter.end_search
          @search_threads_running.signal
        end
      end

      def lookup_book(isbn)
        Thread.new do
          start_search
          results = Alexandria::BookProviders.isbn_search(isbn)
          book = results[0]
          cover_uri = results[1]
          @book_results[isbn] = results
          set_cover_image_async(isbn, cover_uri)

          @barcodes_treeview.model.freeze_notify do
            @barcodes_treeview.model.each do |model, path, iter|
              if iter[0] == isbn
                iter[2] = book.title
                model.row_changed(path, iter)
              end
            end
          end

          @add_button.sensitive = true
        rescue StandardError => ex
          log.error { "Book Search failed: #{ex.message}" }
          log << ex if log.error?
        ensure
          stop_search
        end
      end

      def set_cover_image_async(isbn, cover_uri)
        Thread.new do
          pixbuf = nil
          if cover_uri
            image_data = nil
            if URI.parse(cover_uri).scheme.nil?
              File.open(cover_uri, "r") do |io|
                image_data = io.read
              end
            else
              image_data = URI.parse(cover_uri).read
            end
            loader = GdkPixbuf::PixbufLoader.new
            loader.last_write(image_data)
            pixbuf = loader.pixbuf
          else
            pixbuf = Icons::BOOK
          end

          @barcodes_treeview.model.freeze_notify do
            @barcodes_treeview.model.each do |model, path, iter|
              if iter[0] == isbn
                iter[1] = pixbuf
                model.row_changed(path, iter)
              end
            end
          end
        rescue StandardError => ex
          log.error do
            "Failed to load cover image icon: #{ex.message}"
          end
          log << ex if log.error?
        end
      end

      def on_destroy
        MainApp.instance.ui_manager.set_status_label("")
        notify_end_add_by_isbn
        # TODO: possibly make sure all threads have stopped running
        @animation.destroy
      end

      def setup_scanner_area
        @scanner_buffer = ""
        scanner_name = @prefs.barcode_scanner

        @scanner = Alexandria::Scanners.find_scanner(scanner_name) ||
          Alexandria::Scanners.default_scanner # CueCat is default

        log.debug { "Using #{@scanner.name} scanner" }
        message = _("Ready to use %s barcode scanner") % @scanner.name
        MainApp.instance.ui_manager.set_status_label(message)

        @prev_time = 0
        @interval = 0

        @animation = BarcodeAnimation.new
        @scan_frame.add(@animation.canvas)

        # attach signals
        @scan_area.signal_connect("button-press-event") do |_widget, _event|
          @scan_area.grab_focus
        end
        @scan_area.signal_connect("focus-in-event") do |_widget, _event|
          @barcode_label.label =
            _(format("%s _Barcode Scanner Ready", _(@scanner.display_name)))
          @scanner_buffer = ""
          begin
            @animation.set_active
          rescue StandardError => ex
            log << ex if log.error?
          end
        end
        @scan_area.signal_connect("focus-out-event") do |_widget, _event|
          @barcode_label.label = _("Click below to scan _barcodes")
          @scanner_buffer = ""
          @animation.set_passive
          # @scanner_background.destroy
        end

        @@debug_index = 0
        @scan_area.signal_connect("key-press-event") do |_button, event|
          # log.debug { event.keyval }
          # event.keyval == 65293 means Enter key
          # HACK, this disallows numeric keypad entry of data...
          if event.keyval < 255
            if @scanner_buffer.empty?
              if event.keyval.chr == "`" # backtick key for devs
                developer_test_scan
                next
              else
                # this is our first character, notify user
                log.debug { "Scanning! Received first character." }
              end
              play_sound("scanning")
            end
            @scanner_buffer << event.keyval.chr

            # calculating average interval between input characters
            if @prev_time.zero?
              @prev_time = Time.now.to_f
            else
              now = Time.now.to_f
              if @interval.zero?
                @interval = now - @prev_time
              else
                new_interval = now - @prev_time
                @interval = (@interval + new_interval) / 2.0
              end
              @prev_time = now
            end

            # if average interval is greater than around 45 milliseconds,
            # then it's probably a human typing characters

            if @scanner.match? @scanner_buffer

              Thread.new(@interval, @scanner_buffer) do |interval, buffer|
                log.debug { "Waiting for more scanner input" }
                GLib::Idle.add do
                  @animation.manual_input
                  false
                end
                time_to_wait = [3, interval * 4].min
                sleep(time_to_wait)
                if buffer == @scanner_buffer
                  log.debug { "Buffer unchanged; scanning complete" }
                  GLib::Idle.add do
                    @animation.scanner_input
                    false
                  end
                  read_barcode_scan
                  log.debug { "Avg interval between chars: #{@interval}" }
                  @prev_time = 0
                  @interval = 0

                else
                  log.debug do
                    "Buffer has changed while waiting; reading more characters"
                  end
                end
              end

            end
          end
        end

        # @sound_player = SoundEffectsPlayer.new
        @sound_players = {}
        @sound_players["scanning"] = SoundEffectsPlayer.new
        @sound_players["good_scan"] = SoundEffectsPlayer.new
        @sound_players["bad_scan"] = SoundEffectsPlayer.new
        @test_scan = false
      end

      def play_sound(effect)
        if effect == "scanning"
          log.debug { "Effect: #{effect}, playing: #{@prefs.play_scanning_sound}" }
          return unless @prefs.play_scanning_sound

          @sound_players["scanning"].play("scanning")
        else
          log.debug { "Effect: #{effect}, playing: #{@prefs.play_scan_sound}" }
          return unless @prefs.play_scan_sound

          # sleep(0.5) # "scanning" effect lasts 0.5 seconds, wait for it to end
          @sound_players[effect].play(effect)
        end
      end

      def developer_test_scan
        log.info { "Developer test scan" }
        scans = [".C3nZC3nZC3n2ChnWENz7DxnY.cGen.ENr7C3j3C3f1Dxj3Dq.",
                 ".C3nZC3nZC3n2ChnWENz7DxnY.cGen.ENr7C3z0CNj3Dhj1EW.",
                 ".C3nZC3nZC3n2ChnWENz7DxnY.cGen.ENr7C3r2DNbXCxTZCW.",
                 ".C3nZC3nZC3n2ChnWENz7DxnY.cGf2.ENr7C3z0DNn0ENnWE3nZDhP6.",
                 ".C3nZC3nZC3n2ChnWENz7DxnY.cGen.ENr7CNT2CxT2ChP0Dq.",
                 ".C3nZC3nZC3n2ChnWENz7DxnY.cGen.ENr7CNT6E3f7CNbWDa.",
                 ".C3nZC3nZC3n2ChnWENz7DxnY.cGen.ENr7C3b3ENjYDxv3EW.",
                 ".C3nZC3nZC3n2ChnWENz7DxnY.cGen.ENr7C3b2DxjZE3b3Dq.",
                 ".C3nZC3nZC3n2ChnWENz7DxnY.cGen.ENr7C3n6CNr6DxvYDa."]
        @scanner_buffer = scans[@@debug_index % scans.size]
        @@debug_index += 1
        @test_scan = true
        read_barcode_scan
        @test_scan = false
      end

      def init_treeview
        liststore = Gtk::ListStore.new(String, GdkPixbuf::Pixbuf, String)

        @barcodes_treeview.selection.mode = :multiple

        @barcodes_treeview.model = liststore

        text_renderer = Gtk::CellRendererText.new
        text_renderer.editable = false

        # Add column using our renderer
        col = Gtk::TreeViewColumn.new("ISBN", text_renderer, text: 0)
        @barcodes_treeview.append_column(col)

        # Middle colulmn is cover-image renderer
        pixbuf_renderer = Gtk::CellRendererPixbuf.new
        col = Gtk::TreeViewColumn.new("Cover", pixbuf_renderer)

        col.set_cell_data_func(pixbuf_renderer) do |_column, cell, _model, iter|
          pixbuf = iter[1]
          if pixbuf
            max_height = 25

            if pixbuf.height > max_height
              new_width = pixbuf.width * (max_height.to_f / pixbuf.height)
              pixbuf = pixbuf.scale(new_width, max_height)
            end

            cell.pixbuf = pixbuf
          end
        end

        @barcodes_treeview.append_column(col)

        # Add column using the second renderer
        col = Gtk::TreeViewColumn.new("Title", text_renderer, text: 2)
        @barcodes_treeview.append_column(col)

        @barcodes_treeview.model.signal_connect("row-deleted") do |model, _path|
          @add_button.sensitive = false unless model.iter_first
        end
      end
    end
  end
end
