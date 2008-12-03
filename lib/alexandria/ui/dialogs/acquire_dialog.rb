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
require 'alexandria/scanners/keyboard'
require 'alexandria/scanners/cuecat'

module Alexandria
  module UI

    class BarcodeAnimation < Gtk::VBox

      def initialize()
        super()

        @tid2 = nil
        @box = Gtk::EventBox.new
        pack_start(@box)
        #set_border_width(@pad = 2)
        @pad = 2
        set_size_request(300, 100) # (@width = 48)+(@pad*2), (@height = 48)+(@pad*2))


        @canvas = Gnome::Canvas.new(true)

        @box.add(@canvas)
        @box.signal_connect('size-allocate') { |w,e,*b|
          @width, @height = [e.width,e.height].collect{|i|i - (@pad*2)}
          @canvas.set_size(@width,@height)
          @canvas.set_scroll_region(0,0,@width,@height)
          #puts "canvas size #{@canvas.size[0]}, #{@canvas.size[1]}"
          false
        }
        #signal_connect_after('show') {|w,e| start() }
        # signal_connect_after('hide') {|w,e| stop() }
        @canvas.show()
        @box.show()
        show()
      end

      def set_active
        points = [[0,0], [300,0], [300,100], [0,100]]
        poly_data = {:points => points,
          :fill_color_rgba => 0xFFFFFFFF,
          :join_style => Gdk::GC::JOIN_MITER}
        @scanner_background = Gnome::CanvasPolygon.new(@canvas.root, poly_data)
      end

      def set_passive
        if @scanner_background
          @scanner_background.destroy
        end
      end


      def setup_barcode_display()
        create_ean_barcode_data
      end

      def create_ean_barcode_data
        @index = 0 # -16
        @wipeout = false
        @barcode_bars = []
        @barcode_data = []
        d = '911113123121112331122131113211111123122211132321112311231111'

        @hpos = 0

        while d.size > 0
          space_width = d[0].chr.to_i
          bar_width = d[1].chr.to_i
          d = d[2..-1]

          @barcode_data << [space_width, bar_width]

        end
      end



      def draw_barcode_bars
        return false if destroyed?
        setup_barcode_display() unless defined?(@barcode_data)

        if @wipeout
          if @index >= @barcode_data.size
            @index = -34
            return true
          end
          if @index > -12
            faded_grey = @barcode_bars[0].fill_color_rgba - 5
            if faded_grey < 0
              faded_grey = 0
              stop
            end
            @barcode_bars.each {|b| b.set_fill_color_rgba faded_grey }
          end
          @index += 1
          if @index >= @barcode_data.size
            @barcode_bars.each {|b| b.destroy }
            @wipeout = false
            @index = 0
            @barcode_bars = []
            @hpos = 0
          end
          return true
        end

        if @index < 0
          @index += 1
          return true
        end
        if @index >= @barcode_data.size
          @barcode_bars.each {|b| b.set_fill_color_rgba 0x000000CC }
          @wipeout = true
          return true
        end

        scale = 2.5
        ytop = 5
        ybase = 50


        current_bar = @barcode_data[@index]
        space_width = current_bar[0]
        bar_width = current_bar[1]

        @hpos += space_width
        bar_points = [[scale*(@hpos), ytop], [scale*(@hpos+bar_width), ytop],
                      [scale*(@hpos+bar_width), ybase], [scale*(@hpos), ybase]]
        if not @barcode_bars.empty?
          @barcode_bars.last.fill_color_rgba = 0xFF000080
        end

        @barcode_bars << Gnome::CanvasPolygon.new(@canvas.root,
                                                  { :points => bar_points,
                                                    :fill_color_rgba => 0xFF000090,
                                                    :join_style => Gdk::GC::JOIN_MITER } )
        @hpos += bar_width

        @index += 1
        true
      end



      def start
        unless @tid2
          #puts "starting animation..."
          @tid2 = Gtk::timeout_add(30) { draw_barcode_bars() }
        end
      end

      def stop
        #puts "stopping..."
        Gtk::timeout_remove(@tid2) if @tid2
        @tid2 = nil
      end

      def bg
        @scanner_background
      end

    end


    class AcquireDialog < GladeBase
      include GetText
      include Logging
      extend GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

      def initialize(parent, selected_library=nil, &block)
        super('acquire_dialog.glade')
        @acquire_dialog.transient_for = @parent = parent
        @block = block

        libraries = Libraries.instance.all_regular_libraries
        if selected_library.is_a?(SmartLibrary)
          selected_library = libraries.first
        end
        @combo_libraries.populate_with_libraries(libraries,
                                                 selected_library)

        @add_button.sensitive = false
        setup_scanner_area
        init_treeview
        @book_results = Hash.new
      end

      def on_add
        model = @barcodes_treeview.model
        selection = @barcodes_treeview.selection
        isbns = []
        if selection.count_selected_rows > 0
          model.freeze_notify do
            # capture isbns
            selection.selected_each do |model, path, iter|
              isbns << iter[0]
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
              row_iters << model.get_iter(path)
            end
            row_iters.each do |iter|
              model.remove(iter)
            end

          end
        else
          model.freeze_notify do
            # capture isbns
            model.each do |model, path, iter|
              isbns << iter[0]
            end
            # remove list items
            model.clear
          end
        end

        libraries = Libraries.instance.all_libraries
        library, new_library =
          @combo_libraries.selection_from_libraries(libraries)
        isbns.each do |isbn|
          log.debug { "Adding #{isbn}" }
          result = @book_results[isbn]
          book = result[0]
          cover_uri = result[1]

          unless cover_uri.nil?
            library.save_cover(book, cover_uri)
          end
          library << book
          library.save(book)
        end
      end

      def on_cancel
        @acquire_dialog.destroy
      end

      def on_help
      end

      def read_barcode_scan
        @animator.start
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
          # TODO :: sound
          play_sound("gnometris/turn")

          @barcodes_treeview.model.freeze_notify do
            iter = @barcodes_treeview.model.append
            iter[0] = isbn
            iter[1] = Icons::BOOK
            iter[2] = ""
          end
          lookup_book(isbn)
        else
          log.debug { "was not an ISBN barcode" }
          # TODO :: sound
          play_sound("question")
        end
      end

      private

      def lookup_book(isbn)
        lookup_thread = Thread.new(isbn) do |isbn|
          begin
            results = Alexandria::BookProviders.isbn_search(isbn)
            book = results[0]
            cover_uri = results[1]
            @book_results[isbn] = results
            set_cover_image_async(isbn, cover_uri)
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

      def setup_scanner_area
        @scanner_buffer = ""
        scanner_name = Alexandria::Preferences.instance.barcode_scanner
        @scanner = Alexandria::Scanners::Registry.first
        Alexandria::Scanners::Registry.each do |scanner|
          if scanner.name == scanner_name
            @scanner = scanner
          end
        end
        
        log.debug { "Using #{@scanner.name} scanner" }

        @prev_time = 0
        @interval = 0


        @animator = BarcodeAnimation.new()
        @barcode_canvas.add(@animator)

        # attach signals
        @scan_area.signal_connect("button-press-event") do |widget, event|
          @scan_area.grab_focus
        end
        @scan_area.signal_connect("focus-in-event") do |widget, event|
          @barcode_label.label = _("_Barcode Scanner Ready")
          @scanner_buffer = ""
          begin
            @animator.set_active
            # @frame1.modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(0, 0, 0xEE))
            # @frame1.modify_bg(Gtk::STATE_ACTIVE, Gdk::Color.new(0, 0, 0xEE))
            #points = [[-100,-10], [300,-10], [300,300], [-100,300]]
            # @scanner_background = Gnome::CanvasPolygon.new(@barcode_canvas.root,
            #                                               {:points => points, :fill_color_rgba => 0xFDFDFDFF})
          rescue StandardError => err
            log.error { "Error drawing to Gnome Canvas" }
            log << err if log.error?
          end
        end
        @scan_area.signal_connect("focus-out-event") do |widget, event|
          @barcode_label.label = _("Click below to scan _barcodes")
          @scanner_buffer = ""
          @animator.set_passive
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
              # TODO :: sound
              play_sound("iagno/flip-piece")
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
                  @animator.bg.fill_color_rgba = 0xFFF8C0FF
                  false
                end
                time_to_wait = [3, interval*4].min
                sleep(time_to_wait)
                if buffer == @scanner_buffer
                  log.debug { "Buffer unchanged; scanning complete" }
                  Gtk.idle_add do
                    @animator.bg.fill_color_rgba = 0xFFFFFFFF
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


        # TODO :: sound
        Gnome::Sound.init("localhost")

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
        read_barcode_scan
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

      def play_sound(filename)
        dir = "/usr/share/sounds"
        Gnome::Sound.play("#{dir}/#{filename}.wav")
      end

    end
  end
end
