# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2011 Matijs van Zuijlen
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

require 'gdk_pixbuf2'

module Alexandria
  class DuplicateBookException < NameError
  end

  module UI
    class KeepBadISBNDialog < AlertDialog
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: 'UTF-8')

      def initialize(parent, book)
        super(parent, _("Invalid ISBN '%s'") % book.isbn,
              Gtk::Stock::DIALOG_QUESTION,
              [[Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
               [_('_Keep'), Gtk::Dialog::RESPONSE_OK]],
              _("The book titled '%s' has an invalid ISBN, but still " \
                'exists in the providers libraries.  Do you want to ' \
                'keep the book but change the ISBN or cancel the add?') % book.title)
        self.default_response = Gtk::Dialog::RESPONSE_OK
        show_all and @response = run
        destroy
      end

      def keep?
        @response == Gtk::Dialog::RESPONSE_OK
      end
    end

    class NewBookDialog < BuilderBase
      include Logging
      include GetText
      extend GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: 'UTF-8')

      def initialize(parent, selected_library = nil, &block)
        super('new_book_dialog__builder.glade', widget_names)
        log.info { 'New Book Dialog' }
        @new_book_dialog.transient_for = @parent = parent
        @block = block
        @destroyed = false
        @selected_library = selected_library
        setup_dialog_gui
        @progressbar.hide
      end

      def widget_names
        [:liststore1, :liststore2, :new_book_dialog, :dialog_vbox1,
         :dialog_action_area1, :button_help, :button_cancel,
         :button_add, :table1, :keep_open, :combo_libraries,
         :cellrenderertext1, :eventbox_entry_isbn, :entry_isbn,
         :label3, :hbox2, :eventbox_combo_search, :combo_search,
         :cellrenderertext2, :eventbox_entry_search, :entry_search,
         :button_find, :scrolledwindow, :treeview_results,
         :title_radiobutton, :isbn_radiobutton, :progressbar]
      end

      def setup_dialog_gui
        libraries = Libraries.instance.all_regular_libraries
        if @selected_library.is_a?(SmartLibrary)
          @selected_library = libraries.first
        end
        @combo_libraries.populate_with_libraries(libraries,
                                                 @selected_library)

        @treeview_results.model = Gtk::ListStore.new(String, String,
                                                     Gdk::Pixbuf)
        @treeview_results.selection.mode = Gtk::SELECTION_MULTIPLE
        @treeview_results.selection.signal_connect('changed') do
          @button_add.sensitive = true
        end

        renderer = Gtk::CellRendererPixbuf.new
        col = Gtk::TreeViewColumn.new('', renderer)
        col.set_cell_data_func(renderer) do |_column, cell, _model, iter|
          pixbuf = iter[2]
          max_height = 25

          if pixbuf.height > max_height
            new_width = pixbuf.width * (max_height.to_f / pixbuf.height)
            pixbuf = pixbuf.scale(new_width, max_height)
          end

          cell.pixbuf = pixbuf
        end
        @treeview_results.append_column(col)

        col = Gtk::TreeViewColumn.new('', Gtk::CellRendererText.new,
                                      text: 0)
        @treeview_results.append_column(col)

        @combo_search.active = 0

        # Re-select the last selected criterion.
        # TODO let's do this from a Gconf setting instead, maybe?
        begin
          @title_radiobutton.active = @@last_criterion_was_not_isbn
        rescue NameError
          log.debug { 'initialize @@last_criterion_was_not_isbn as false' }
          @@last_criterion_was_not_isbn = false
        end

        if @@last_criterion_was_not_isbn
          @entry_search.grab_focus
        else
          @entry_isbn.grab_focus
        end

        @find_thread = nil
        @image_thread = nil

        @new_book_dialog.signal_connect('destroy') {
          @new_book_dialog.destroy
          @destroyed = true
        }
      end

      def on_criterion_toggled(item)
        log.debug { 'on_criterion_toggled' }
        return unless item.active?

        # There used to be a strange effect here (pre SVN r1022).
        # When item is first toggled to "Search" the entry_search
        # field was unselectable. One used to have to click the dialog
        # title bar to be able to focus it again. Putting the GUI
        # modifications in an Gtk.idle_add block fixed the problem.

        is_isbn = item == @isbn_radiobutton
        if is_isbn
          Gtk.idle_add do
            @latest_size = @new_book_dialog.size
            @new_book_dialog.resizable = false
            @entry_isbn.grab_focus
            false
          end
        else
          Gtk.idle_add do
            @new_book_dialog.resizable = true
            @new_book_dialog.resize(*@latest_size) unless @latest_size.nil?
            @entry_search.grab_focus
            false
          end
        end
        @entry_isbn.sensitive = is_isbn
        @combo_search.sensitive = !is_isbn
        @entry_search.sensitive = !is_isbn
        @button_find.sensitive = !is_isbn
        @scrolledwindow.visible = !is_isbn
        on_changed(is_isbn ? @entry_isbn : @entry_search)
        unless is_isbn
          @button_add.sensitive =
            @treeview_results.selection.count_selected_rows > 0
        end

        # Remember the last criterion selected (so that we can re-select
        # it when the dialog opens again).
        @@last_criterion_was_not_isbn = !is_isbn

        # @new_book_dialog.present # attempted fix, bring dialog to foreground
      end

      def on_changed(entry)
        ok = !entry.text.strip.empty?
        decode_cuecat?(@entry_isbn) if entry == @entry_isbn
        (entry == @entry_isbn ? @button_add : @button_find).sensitive = ok
      end

      def image_error_dialog(error)
        ErrorDialog.new(
          @parent,
          _('A problem occurred while downloading images'),
          error)
      end

      def get_images_async
        log.info { 'get_images_async' }
        @images = {}
        @image_error = nil
        @image_thread = Thread.new do
          log.info { "New @image_thread #{Thread.current}" }
          begin
            @results.each_with_index do |result, i|
              uri = result[1]
              if uri
                if URI.parse(uri).scheme.nil?
                  File.open(uri, 'r') do |io|
                    @images[i] = io.read
                  end
                else
                  @images[i] = URI.parse(uri).read
                end
              end
            end
          rescue => e
            @image_error = e.message
          end
        end

        Gtk.timeout_add(100) do
          if @image_error
            image_error_dialog(@image_error)
          else
            @images.each_pair do |key, value|
              begin
                loader = Gdk::PixbufLoader.new
                loader.last_write(value)
                pixbuf = loader.pixbuf

                if pixbuf.width > 1
                  iter = @treeview_results.model.get_iter(key.to_s)
                  unless @treeview_results.model.iter_is_valid?(iter)
                    raise 'Iter is invalid! %s' % iter
                  end
                  iter[2] = pixbuf # I bet you this is it!
                end

                @images.delete(key)
              rescue => e
                image_error_dialog(e.message)
              end
            end
          end

          # Stop if the image download thread has stopped.
          if @image_thread.alive?
            log.info { "@image_thread (#{@image_thread}) still alive." }
            true
          else
            log.info { "@image_thread (#{@image_thread}) asleep now." }
            false
          end
        end
      end

      def on_find
        log.info { 'on_find' }
        mode = case @combo_search.active
               when 0
                 BookProviders::SEARCH_BY_TITLE
               when 1
                 BookProviders::SEARCH_BY_AUTHORS
               when 2
                 BookProviders::SEARCH_BY_KEYWORD
               end

        # @progressbar.show
        # progress_pulsing = Gtk.timeout_add(100) do
        #  if @destroyed
        #    false
        #  else
        #    @progressbar.pulse
        #    true
        #  end
        # end

        criterion = @entry_search.text.strip
        @treeview_results.model.clear
        log.info { 'TreeStore Model: %s columns; ref_counts: %s' %
                   [@treeview_results.model.n_columns, @treeview_results.model.ref_count] }

        @find_error = nil
        @results = nil

        @find_thread.kill if @find_thread
        @image_thread.kill if @image_thread

        notify_start_add_by_isbn
        Gtk.idle_add do
          @find_thread = Thread.new do
            log.info { "New @find_thread #{Thread.current}" }
            begin
              Alexandria::BookProviders.instance.add_observer(self)
              @results = Alexandria::BookProviders.search(criterion, mode)

              log.info { "got #{@results.length} results" }
            rescue => e
              @find_error = e.message
            ensure
              Alexandria::BookProviders.instance.delete_observer(self)
              # notify_end_add_by_isbn
            end
          end
          false
        end

        Gtk.timeout_add(100) do
          # This block copies results into the tree view, or shows an
          # error if the search failed.

          # Err... continue == false if @find_error
          continue = if @find_error
                       ErrorDialog.new(@parent,
                                       _('Unable to find matches for your search'),
                                       @find_error)
                       false
                     elsif @results
                       log.info { "Got results: #{@results[0]}..." }
                       @results.each do |book, _cover|
                         s = _('%s, by %s') % [book.title,
                                               book.authors.join(', ')]
                         similar_books = @results.find { |book2, _cover2|
                           book.title == book2.title and
                             book.authors == book2.authors
                         }
                         if similar_books.length > 1
                           s += " (#{book.edition}, #{book.publisher})"
                         end
                         log.info { 'Copying %s into tree view.' % book.title }
                         iter = @treeview_results.model.append
                         iter[0] = s
                         iter[1] = book.ident
                         iter[2] = Icons::BOOK
                       end

                       # Kick off the image download thread.
                       if @find_thread.alive?
                         log.info { "@find_thread (#{@find_thread}) still alive." }
                         true
                       else
                         log.info { "@find_thread (#{@find_thread}) asleep now." }
                         # Not really async now.
                         get_images_async
                         false # continue == false if you get to here. Stop timeout_add.
                       end
                     else
                       # Stop if the book find thread has stopped.
                       @find_thread.alive?
                     end
          # continue == false if @find_error OR if results are returned
          # timeout_add ends if continue is false!

          unless continue
            unless @find_thread.alive? # This happens after find_thread is done
              unless @destroyed
                # Gtk.timeout_remove(progress_pulsing)
                # @progressbar.hide
                notify_end_add_by_isbn
                @button_add.sensitive = false
              end
            end
          end

          continue # timeout_add loop condition
        end
      end

      def decode_cuecat?(entry) # srsly?
        if entry.text =~ /^\..*?\..*?\.(.*?)\.$/
          tmp = Regexp.last_match[1].tr('a-zA-Z0-9+-', ' -_')
          tmp = ((32 + tmp.length * 3 / 4).to_i.chr << tmp).unpack('u')[0]
          tmp.chomp!("\000")
          entry.text = tmp.gsub!(/./) { |c| (c[0] ^ 67).chr }
          if entry.text.count('^ -~') > 0
            entry.text = 'Bad scan result'
          end
        end
      end

      def on_results_button_press_event(_widget, event)
        # double left click
        if event.event_type == Gdk::Event::BUTTON2_PRESS and
          event.button == 1

          on_add
        end
      end

      def add_single_book_by_isbn(library, is_new)
        # Perform the ISBN search via the providers.
        isbn = begin
                 Library.canonicalise_isbn(@entry_isbn.text)
               rescue
                 raise _("Couldn't validate the EAN/ISBN you " \
                         'provided.  Make sure it is written ' \
                         'correctly, and try again.')
               end
        assert_not_exist(library, @entry_isbn.text)
        @button_add.sensitive = false
        notify_start_add_by_isbn
        Gtk.idle_add do

          @find_thread = Thread.new do
            log.info { "New @find_thread #{Thread.current}" }
            begin
              # MAJOR HACK, add this again...
              Alexandria::BookProviders.instance.add_observer(self)
              book, cover_url = Alexandria::BookProviders.isbn_search(isbn)
              # prov = FakeBookProviders.new()
              # prov.add_observer(self)
              # book, cover_url = prov.isbn_search(isbn)

              notify_end_add_by_isbn

              if book

                puts "adding book #{book} to library"
                add_book_to_library(library, book, cover_url)
                @entry_isbn.text = ''

                post_addition([book], library, is_new)
              else
                post_addition([], library, is_new)
              end
            rescue => e
              unless e.is_a? Alexandria::BookProviders::NoResultsError
                puts e.message
                puts e.backtrace.join("\n> ")
              end
              @find_error = e.message
              @button_add.sensitive = true
              notify_end_add_by_isbn
            ensure
              Alexandria::BookProviders.instance.delete_observer(self)
              notify_end_add_by_isbn
            end
          end

          false
        end
      end

      def add_selected_books(library, _is_new)
        books_to_add = []
        @treeview_results.selection.selected_each do |_model, _path, iter|
          @results.each do |book, cover|
            next unless book.ident == iter[1]
            begin
              next unless assert_not_exist(library, book.isbn)
            rescue Alexandria::Library::NoISBNError
              puts 'noisbn'
              book.isbn = book.saved_ident = nil
              books_to_add << [book, cover]
              next
            rescue Alexandria::Library::InvalidISBNError
              puts "invalidisbn #{book.isbn}"
              next unless
              KeepBadISBNDialog.new(@parent, book).keep?
              book.isbn = book.saved_ident = nil
            end
            books_to_add << [book, cover]
          end

        end
        books_to_add.each do |book, cover_uri|
          add_book_to_library(library, book, cover_uri)
        end
        books_to_add.map(&:first) # array of Books only
      end

      def add_book_to_library(library, book, cover_uri)
        unless cover_uri.nil?
          library.save_cover(book, cover_uri)
        end
        library << book
        library.save(book)
      end

      def post_addition(books, library, is_new_library)
        puts "post_addition #{books.size}"
        return if books.empty?

        # books, a 1d array of Alexandria::Book
        @block.call(books, library, is_new_library)

        if @keep_open.active?
          # TODO reset and clear fields
          if @@last_criterion_was_not_isbn
            @entry_search.select_region(0, -1) # select all, ready to delete
            @treeview_results.model.clear
            @entry_search.grab_focus
          else
            @button_add.sensitive = true #
            @entry_isbn.text = '' # blank ISBN field
            @entry_isbn.grab_focus
          end

        else
          # Now we can destroy the dialog and go back to the main
          # application.
          @new_book_dialog.destroy
        end
      end

      def on_add
        return unless @button_add.sensitive?
        @find_thread.kill if @find_thread
        @image_thread.kill if @image_thread

        begin
          libraries = Libraries.instance.all_libraries
          library, is_new_library =
            @combo_libraries.selection_from_libraries(libraries)

          # book_was_added = false

          if @isbn_radiobutton.active?
            add_single_book_by_isbn(library, is_new_library)
          else
            books = add_selected_books(library, is_new_library)
            post_addition(books, library, is_new_library)
          end

          # Do not destroy if there is no addition.
          #          return unless book_was_added

        rescue => e
          ErrorDialog.new(@parent, _("Couldn't add the book"), e.message)
        end
        # books_to_add
      end

      def on_cancel
        @find_thread.kill if @find_thread
        @image_thread.kill if @image_thread
        @new_book_dialog.destroy
      end

      def notify_start_add_by_isbn
        main_progress_bar = MainApp.instance.appbar.children.first
        main_progress_bar.visible = true
        @progress_pulsing = Gtk.timeout_add(100) do
          if @destroyed
            false
          else
            main_progress_bar.pulse
            true
          end
        end
      end

      def notify_end_add_by_isbn
        MainApp.instance.appbar.children.first.visible = false
        Gtk.timeout_remove(@progress_pulsing)
      end

      def update(status, provider)
        Gtk.queue do
          messages = {
            searching: _("Searching Provider '%s'..."),
            error: _("Error while Searching Provider '%s'"),
            not_found: _("Not Found at Provider '%s'"),
            found: _("Found at Provider '%s'")
          }
          message = messages[status] % provider
          log.debug { "update message : #{message}" }

          # @parent.appbar.status = message
          MainApp.instance.appbar.status = message # HACKish
          # false
        end
      end

      def on_focus
        if @isbn_radiobutton.active? and @entry_isbn.text.strip.empty?
          clipboard = Gtk::Clipboard.get(Gdk::Selection::CLIPBOARD)
          if (text = clipboard.wait_for_text)
            if Library.valid_isbn?(text) or Library.valid_ean?(text) or
              Library.valid_upc?(text)
              Gtk.idle_add do

                @entry_isbn.text = text
                @entry_isbn.grab_focus
                @entry_isbn.select_region(0, -1) # select all...
                # @button_add.grab_focus
                false
              end
              log.debug { "Setting ISBN field to #{text}" }
              puts text # required, strangely, to prevent GUI strangeness
              # above last checked with ruby-gnome2 0.17.1 2009-12-09
              # if this puts is commented out, the cursor disappears
              # from the @entry_isbn box... weird, ne? - CathalMagus
            end
          end
        end
      end

      def on_clicked(widget, event)
        if event.event_type == Gdk::Event::BUTTON_PRESS and
          event.button == 1

          radio, target_widget, box2, box3 = case widget
                                             when @eventbox_entry_search
                                               [@title_radiobutton, @entry_search,
                                                @eventbox_combo_search, @eventbox_entry_isbn]

                                             when @eventbox_combo_search
                                               [@title_radiobutton, @combo_search,
                                                @eventbox_entry_search, @eventbox_entry_isbn]

                                             when @eventbox_entry_isbn
                                               [@isbn_radiobutton, @entry_isbn,
                                                @eventbox_entry_search, @eventbox_combo_search]
                                             end
          radio.active = true
          target_widget.grab_focus
          widget.above_child = false
          box2.above_child = box3.above_child = true
        end
      end

      def on_help
        Alexandria::UI.display_help(@preferences_dialog, 'add-book-by-isbn')
      end

      #######
      private
      #######

      def assert_not_exist(library, isbn)
        # Check that the book doesn't already exist in the library.
        isbn13 = Library.canonicalise_ean(isbn)
        puts isbn13
        if (book = library.find { |bk| bk.isbn == isbn13 })
          raise DuplicateBookException, _("'%s' already exists in '%s' (titled '%s').") % \
            [isbn, library.name, book.title.sub('&', '&amp;')]
        end
        true
      end
    end
  end
end
