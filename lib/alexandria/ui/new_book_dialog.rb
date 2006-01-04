# Copyright (C) 2004-2006 Laurent Sansonetti
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
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

require 'gdk_pixbuf2'

module Alexandria
module UI
    class KeepBadISBNDialog < AlertDialog
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent, book)
            super(parent, _("Invalid ISBN '%s'") % book.isbn,
                  Gtk::Stock::DIALOG_QUESTION,
                  [[Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                   [_("_Keep"), Gtk::Dialog::RESPONSE_OK]],
                  _("The book titled '%s' has an invalid ISBN, but still " +
                    "exists in the providers libraries.  Do you want to " +
                    "keep the book but change the ISBN or cancel the add?") \
                    % book.title)
            self.default_response = Gtk::Dialog::RESPONSE_OK
            show_all and @response = run
            destroy
        end

        def keep?
            @response == Gtk::Dialog::RESPONSE_OK
        end
    end

    class NewBookDialog < GladeBase
        include GetText
        extend GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent, selected_library=nil, &block)
            super('new_book_dialog.glade')
            @new_book_dialog.transient_for = @parent = parent
            @block = block

            libraries = Libraries.instance.all_regular_libraries
            if selected_library.is_a?(SmartLibrary)
                selected_library = libraries.first
            end
            @combo_libraries.populate_with_libraries(libraries,
                                                     selected_library) 

            @treeview_results.model = Gtk::ListStore.new(String, String,
                Gdk::Pixbuf)
            @treeview_results.selection.mode = Gtk::SELECTION_MULTIPLE
            @treeview_results.selection.signal_connect('changed') do
                @button_add.sensitive = true
            end

            renderer = Gtk::CellRendererPixbuf.new
            col = Gtk::TreeViewColumn.new("", renderer)
            col.set_cell_data_func(renderer) do |column, cell, model, iter|
                pixbuf = iter[2]
                max_height = 25 

                if pixbuf.height > max_height
                    new_width = pixbuf.width * (max_height.to_f / pixbuf.height)
                    pixbuf = pixbuf.scale(new_width, max_height)
                end

                cell.pixbuf = pixbuf
            end
            @treeview_results.append_column(col)

            col = Gtk::TreeViewColumn.new("", Gtk::CellRendererText.new, 
                                          :text => 0)
            @treeview_results.append_column(col)
            @entry_isbn.grab_focus
            @combo_search.active = 0

            # Re-select the last selected criterion.
            begin
                @title_radiobutton.active = @@last_criterion_was_not_isbn
            rescue NameError
                @@last_criterion_was_not_isbn = false
            end 

            @find_thread = nil
            @image_thread = nil
        end

        def on_criterion_toggled(item)
            return unless item.active?
            if is_isbn = item == @isbn_radiobutton
                @latest_size = @new_book_dialog.size
                @new_book_dialog.resizable = false 
            else
                @new_book_dialog.resizable = true 
                @new_book_dialog.resize(*@latest_size) unless @latest_size.nil?
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
        end

        def on_changed(entry)
            ok = !entry.text.strip.empty?
            (entry == @entry_isbn ? @button_add : @button_find).sensitive = ok
        end

        def image_error_dialog(error)
            ErrorDialog.new(
                @parent,
                _("A problem occurred while downloading images"),
                error)
        end

        def get_images_async
            @images = {}
            @image_error = nil

            @image_thread = Thread.new do
                begin
                    @results.each_with_index do |result, i|
                        uri = result[1]
                        if uri
                            @images[i] = URI.parse(uri).read
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
                                iter[2] = pixbuf
                            end

                            @images.delete(key)
                        rescue => e
                            image_error_dialog(e.message)
                        end
                    end
                end

                # Stop if the image download thread has stopped.
                @image_thread.alive?
            end
        end

        def on_find
            mode = case @combo_search.active
                when 0
                    BookProviders::SEARCH_BY_TITLE
                when 1
                    BookProviders::SEARCH_BY_AUTHORS
                when 2
                    BookProviders::SEARCH_BY_KEYWORD
            end

            criterion = @entry_search.text.strip
            @treeview_results.model.clear
            @new_book_dialog.sensitive = false
            @find_error = nil
            @results = nil

            @find_thread.kill if @find_thread
            @image_thread.kill if @image_thread
            
            @find_thread = Thread.new do
                begin
                    @results = Alexandria::BookProviders.search(criterion, mode)
                    puts "got #{@results.length} results" if $DEBUG
                rescue => e
                    @find_error = e.message
                end
            end

            Gtk.timeout_add(100) do
                # This block copies results into the tree view, or shows an
                # error if the search failed.

                continue = if @find_error
                    ErrorDialog.new(@parent,
                                    _("Unable to find matches for your search"),
                                    @find_error)
                    false
                elsif @results
                    @results.each do |book, cover|
                        s = _("%s, by %s") % [ book.title,
                                               book.authors.join(', ') ]

                        if @results.find { |book2, cover2|
                                            book.title == book2.title and
                                            book.authors == book2.authors
                                         }.length > 1
                            s += " (#{book.edition}, #{book.publisher})"
                        end

                        iter = @treeview_results.model.append
                        iter[0] = s
                        iter[1] = book.isbn
                        iter[2] = Icons::BOOK
                    end

                    # Kick off the image download thread.
                    get_images_async

                    false
                else
                    # Stop if the book find thread has stopped.
                    @find_thread.alive?
                end

                unless continue
                    @new_book_dialog.sensitive = true
                    @button_add.sensitive = false 
                end
                continue
            end
        end

        def on_results_button_press_event(widget, event)
            # double left click
            if event.event_type == Gdk::Event::BUTTON2_PRESS and
               event.button == 1 

                on_add
            end
        end

        def on_add
            return unless @button_add.sensitive?
            @find_thread.kill if @find_thread
            @image_thread.kill if @image_thread

            begin
                libraries = Libraries.instance.all_libraries
                library, new_library = 
                    @combo_libraries.selection_from_libraries(libraries)
                books_to_add = []

                if @isbn_radiobutton.active?
                    # Perform the ISBN search via the providers.
                    isbn = begin
                        Library.canonicalise_isbn(@entry_isbn.text)
                    rescue
                        raise _("Couldn't validate the EAN/ISBN you " +
                                "provided.  Make sure it is written " +
                                "correcty, and try again.")
                    end
                    assert_not_exist(library, @entry_isbn.text)
                    books_to_add << Alexandria::BookProviders.isbn_search(isbn)
                else
                    @treeview_results.selection.selected_each do |model, path, 
                                                                  iter| 
                        @results.each do |book, cover|
                            next unless book.isbn == iter[1]
                            begin
                                next unless
                                    assert_not_exist(library, book.isbn)
                            rescue Alexandria::Library::InvalidISBNError
                                next unless
                                    KeepBadISBNDialog.new(@parent, book).keep?
                                book.isbn = book.saved_ident = ""
                            end
                            books_to_add << [book, cover]
                        end
                    end
                end 

                # Save the books in the library.
                books_to_add.each do |book, cover_uri|
                    unless cover_uri.nil?
                        library.save_cover(book, cover_uri)
                    end
                    library << book
                    library.save(book)
                end

                # Do not destroy if there is no addition.
                return if books_to_add.empty?

                # Now we can destroy the dialog and go back to the main 
                # application.
                @new_book_dialog.destroy
                @block.call(books_to_add.map { |x| x.first }, 
                            library, 
                            new_library)
            rescue => e
                ErrorDialog.new(@parent, _("Couldn't add the book"), e.message)
            end
        end

        def on_cancel
            @find_thread.kill if @find_thread
            @image_thread.kill if @image_thread
            @new_book_dialog.destroy
        end

        def on_focus
            if @isbn_radiobutton.active? and @entry_isbn.text.strip.empty?
                clipboard = Gtk::Clipboard.get(Gdk::Selection::CLIPBOARD)
                if text = clipboard.wait_for_text
                    @entry_isbn.text = text if
                        Library.valid_isbn?(text) or Library.valid_ean?(text) or 
                        Library.valid_upc?(text)
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
            begin
                Gnome::Help.display('alexandria', 'add-book-by-isbn')
            rescue => e 
                ErrorDialog.new(@preferences_dialog, e.message)
            end
        end

        #######
        private
        #######

        def assert_not_exist(library, isbn)
            # Check that the book doesn't already exist in the library.
            canonical = Library.canonicalise_isbn(isbn)
            if book = library.find { |book| book.isbn == canonical }
                raise _("'%s' already exists in '%s' (titled '%s').") % \
                        [ isbn, library.name, book.title ] 
            end
            true
        end
    end
end
end
