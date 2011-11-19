# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2007 Cathal Mc Ginley
#
# Alexandria is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# Alexandria is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with Alexandria; see the file COPYING.  If not,
# write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301 USA.

#require 'monitor'
require 'alexandria/scanners/cuecat'
require 'alexandria/scanners/keyboard'

require 'alexandria/ui/sound'
require 'alexandria/ui/dialogs/barcode_animation'

module Alexandria
  module UI

    require 'thread'
    require 'monitor'

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
          @count -= 1 unless (@count == 0)
        end
      end

    end


    class AcquireDialog < BuilderBase
      include GetText
      include Logging
      extend GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      def initialize(parent, selected_library=nil, &block)
        super('acquire_dialog__builder.glade', widget_names)
        @acquire_dialog.transient_for = @parent = parent
        @block = block

        libraries = Libraries.instance.all_regular_libraries
        if selected_library.is_a?(SmartLibrary)
          selected_library = libraries.first
        end
        @combo_libraries.populate_with_libraries(libraries,
                                                 selected_library)

        @add_button.sensitive = false
        @prefs = Alexandria::Preferences.instance
        setup_scanner_area
        init_treeview
        @book_results = Hash.new
        
        @search_thread_counter = SearchThreadCounter.new
        @search_threads_running = @search_thread_counter.new_cond

      end

      def widget_names
        [:acquire_dialog, :dialog_vbox1, :dialog_action_area1,
         :help_button, :cancel_button, :add_button, :vbox1,
         :barcode_label, :scan_area, :scan_frame, :scrolledwindow1,
         :barcodes_treeview, :hbox1, :label1, :combo_libraries]
      end

      def book_in_library(isbn10, library)
        begin
          isbn13 = Library.canonicalise_ean(isbn10)
          # puts "new book #{isbn10} (or #{isbn13})"
          match = library.find do |book|
            # puts "testing #{book.isbn}"
            (book.isbn == isbn10 || book.isbn == isbn13)
            #puts "book #{book.isbn}"
            #book == new_book 
          end
          # puts "book_in_library match #{match.inspect}"
          (not match.nil?)
        rescue Exception => ex
          log.warn { "Failed to check for book #{isbn10} in library #{library}" }
          true
        end
      end

      def on_add
        model = @barcodes_treeview.model

        libraries = Libraries.instance.all_libraries
        library, is_new_library =
          @combo_libraries.selection_from_libraries(libraries)

        # NOTE at this stage, the ISBN is 10-digit...
        #

        selection = @barcodes_treeview.selection
        isbns = []
        isbn_duplicates = []

        adding_a_selection = false

        if selection.count_selected_rows > 0

          adding_a_selection = true

          model.freeze_notify do
            # capture isbns
            selection.selected_each do |model, path, iter|
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
            # remove list items (complex, cf. tutorial...)
            # http://ruby-gnome2.sourceforge.jp/hiki.cgi?tut-treeview-model-remove
            #row_refs = []
            #paths = selection.selected_rows
            #paths.each do |path|
            #    row_refs << Gtk::TreeRowReference.new(model, path)
            #end
            #row_refs.each do |ref|
            #    model.remove(model.get_iter(ref.path))
            #end

            # try it this way... works because of persistent iters
            row_iters = []
            selection.selected_rows.each do |path|
              iter = model.get_iter(path)
              isbn = iter[0]
              if book_in_library(isbn, library)
                log.debug { "#{isbn} is a duplicate" }
              ##elsif isbns.include? isbn
                # this won't work since multiple scans of the same
                # book have the same isbn (so we can't refrain from removing
                # one, we'd end up not removing any)
                ## TODO add another column in the iter, like "isbn/01"
                # that would allow this kind of behaviour...

              elsif (not @book_results.has_key?(isbn)) #HAX
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
            model.each do |model, path, iter|
              isbn = iter[0]
              if (not @book_results.has_key?(isbn))
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
            if (isbn_duplicates.empty? and (not adding_a_selection))
              model.clear # TODO unless!!!
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
            
            unless cover_uri.nil?
              library.save_cover(book, cover_uri)
            end
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
          ErrorDialog.new(@parent, title, message)
        end

        @block.call(books, library, is_new_library)
      end

      def on_cancel
        @acquire_dialog.destroy
      end

      def on_help
      end

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
          # TODO :: use an AppFacade
          # isbn =  LookupBook.get_isbn(barcode_text)
        rescue StandardError => err
          log.error { "Bad scan:  #{@scanner_buffer} #{err}" }
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
        Gtk.idle_add do
          main_progress_bar = MainApp.instance.appbar.children.first
          main_progress_bar.visible = true
          @progress_pulsing = Gtk.timeout_add(100) do
            unless @destroyed
              main_progress_bar.pulse
              true
            else
              false
            end
          end
          false
        end
      end

      def notify_end_add_by_isbn
        Gtk.idle_add do
          MainApp.instance.appbar.children.first.visible = false
          Gtk::timeout_remove(@progress_pulsing) if @progress_pulsing
          false
        end
      end

      def update(status, provider)
        Gtk.idle_add do
          messages = {
            :searching => _("Searching Provider '%s'..."),
            :error => _("Error while Searching Provider '%s'"),
            :not_found => _("Not Found at Provider '%s'"),
            :found => _("Found at Provider '%s'")
          }
          message = messages[status] % provider
          log.debug { "update message : #{message}" }
          # @parent.appbar.status = message
          MainApp.instance.ui_manager.set_status_label( message )
          false
        end
      end

      # end copy-n-paste

      private 
      
      def start_search         
        @search_thread_counter.synchronize do 
          if @search_thread_counter.count == 0
            @search_thread_counter.new_search
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
          else
            @search_thread_counter.new_search
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
        lookup_thread = Thread.new(isbn) do |isbn|
          begin
            start_search
            results = Alexandria::BookProviders.isbn_search(isbn)
            book = results[0]
            cover_uri = results[1]
            @book_results[isbn] = results
            set_cover_image_async(isbn, cover_uri)
            # TODO add this as a block to Gtk.queue (needs new overall gui design)
            @barcodes_treeview.model.freeze_notify do
              iter = @barcodes_treeview.model.each do |model, path, iter|
                if iter[0] == isbn
                  iter[2] = book.title
                  model.row_changed(path, iter)
                end
              end
            end

            @add_button.sensitive = true
          rescue StandardError => err
            log.error { "Book Search failed: #{err.message}"}
            log << err if log.error?
          ensure
            stop_search
          end
        end
      end

      def set_cover_image_async(isbn, cover_uri)
        image_thread = Thread.new(isbn, cover_uri) do |isbn, cover_uri|
          begin
            pixbuf = nil
            if cover_uri
              image_data = nil
              if URI.parse(cover_uri).scheme.nil?
                File.open(cover_uri, "r") do |io|
                  image = io.read
                end
              else
                image_data = URI.parse(cover_uri).read
              end
              loader = Gdk::PixbufLoader.new
              loader.last_write(image_data)
              pixbuf = loader.pixbuf
            else
              pixbuf = Icons::BOOK
            end

            @barcodes_treeview.model.freeze_notify do
              iter = @barcodes_treeview.model.each do |model, path, iter|
                if iter[0] == isbn
                  iter[1] = pixbuf
                  model.row_changed(path, iter)
                end
              end
            end


          rescue StandardError => err
            log.error {
              "Failed to load cover image icon: #{err.message}"
            }
            log << err if log.error?

          end
        end
      end

      def on_destroy
        MainApp.instance.ui_manager.set_status_label( "" )
        notify_end_add_by_isbn
        # TODO possibly make sure all threads have stopped running
        @animation.destroy
      end

      def setup_scanner_area
        @scanner_buffer = ""
        scanner_name = @prefs.barcode_scanner
        @scanner = Alexandria::Scanners::Registry.first # CueCat is default
        Alexandria::Scanners::Registry.each do |scanner|
          if scanner.name == scanner_name
            @scanner = scanner
          end
        end

        log.debug { "Using #{@scanner.name} scanner" }
        message = _("Ready to use %s barcode scanner") % @scanner.name
        MainApp.instance.ui_manager.set_status_label( message )

        @prev_time = 0
        @interval = 0


        @animation = BarcodeAnimation.new()
        @scan_frame.add(@animation.canvas)

        # attach signals
        @scan_area.signal_connect("button-press-event") do |widget, event|
          @scan_area.grab_focus
        end
        @scan_area.signal_connect("focus-in-event") do |widget, event|
          @barcode_label.label = _("%s _Barcode Scanner Ready" % _(@scanner.display_name))
          @scanner_buffer = ""
          begin
            @animation.set_active
          rescue StandardError => err
            log << err if log.error?
          end
        end
        @scan_area.signal_connect("focus-out-event") do |widget, event|
          @barcode_label.label = _("Click below to scan _barcodes")
          @scanner_buffer = ""
          @animation.set_passive
          # @scanner_background.destroy
        end

        @@debug_index = 0
        @scan_area.signal_connect("key-press-event") do |button, event|
          #log.debug { event.keyval }
            # event.keyval == 65293 means Enter key
          # HACK, this disallows numeric keypad entry of data...
          if event.keyval < 255
            if @scanner_buffer.empty?
              if event.keyval.chr == '`' # backtick key for devs
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
                log.debug { "Waiting for more scanner input..." }
                Gtk.idle_add do
                  @animation.manual_input
                  false
                end
                time_to_wait = [3, interval*4].min
                sleep(time_to_wait)
                if buffer == @scanner_buffer
                  log.debug { "Buffer unchanged; scanning complete" }
                  Gtk.idle_add do
                    @animation.scanner_input
                    false
                  end
                  read_barcode_scan
                  log.debug { "Avg interval between chars: #{@interval}" }
                  @prev_time = 0
                  @interval = 0

                else
                  log.debug { "Buffer has changed while waiting, reading more characters..." }
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
        # HACK, do some thread waiting, if possible
        puts "scanning sound : #{@prefs.play_scanning_sound}"
        puts "scan sound:      #{ @prefs.play_scan_sound}"
        if effect == "scanning"
          puts effect
          return unless  @prefs.play_scanning_sound
          Gtk.idle_add do
            @sound_players["scanning"].play("scanning")
            false
          end
        else
          puts effect
          return unless @prefs.play_scan_sound
          Gtk.idle_add do
            #sleep(0.5) # "scanning" effect lasts 0.5 seconds, wait for it to end
            @sound_players[effect].play(effect)
            false
          end
        end
      end

      def developer_test_scan
        log.info { "Developer test scan." }
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
        liststore = Gtk::ListStore.new(String, Gdk::Pixbuf, String)

        @barcodes_treeview.selection.mode = Gtk::SELECTION_MULTIPLE

        @barcodes_treeview.model = liststore

        text_renderer = Gtk::CellRendererText.new
        text_renderer.editable = false

        # Add column using our renderer
        col = Gtk::TreeViewColumn.new("ISBN", text_renderer, :text => 0)
        @barcodes_treeview.append_column(col)

        # Middle colulmn is cover-image renderer
        pixbuf_renderer = Gtk::CellRendererPixbuf.new
        col = Gtk::TreeViewColumn.new("Cover", pixbuf_renderer)

        col.set_cell_data_func(pixbuf_renderer) do |column, cell, model, iter|
          pixbuf = iter[1]
          if (pixbuf)
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
        col = Gtk::TreeViewColumn.new("Title", text_renderer, :text => 2)
        @barcodes_treeview.append_column(col)


        @barcodes_treeview.model.signal_connect("row-deleted") do |model, path|
          if not model.iter_first
            @add_button.sensitive = false
          end
        end

      end

    end
  end
end
