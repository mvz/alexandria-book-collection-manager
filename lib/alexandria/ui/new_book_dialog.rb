# Copyright (C) 2004 Laurent Sansonetti
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

module Alexandria
module UI
    class NewBookDialog < GladeBase
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent, libraries, selected_library=nil, &block)
            super('new_book_dialog.glade')
            @new_book_dialog.transient_for = @parent = parent
            @block = block
            @libraries = libraries

            popdown = libraries.map { |x| x.name }
            if selected_library
              popdown.delete selected_library.name
              popdown.unshift selected_library.name
            end
            @combo_libraries.popdown_strings = popdown
            @combo_libraries.sensitive = libraries.length > 1

            @treeview_results.model = Gtk::ListStore.new(String, String)
            @treeview_results.selection.signal_connect('changed') { @button_add.sensitive = true }
            col = Gtk::TreeViewColumn.new("", Gtk::CellRendererText.new, :text => 0)
            @treeview_results.append_column(col)
        end
   
        def on_criterion_toggled(item)
            ok = item == @isbn_radiobutton
            @entry_isbn.sensitive = ok 
            @entry_title.sensitive = !ok 
            @button_find.sensitive = !ok
            @scrolledwindow.visible = !ok
            on_changed(ok ? @entry_isbn : @entry_title)
            @button_add.sensitive = !@treeview_results.selection.selected.nil? unless ok
        end

        def on_changed(entry)
            ok = !entry.text.strip.empty?
            (entry == @entry_isbn ? @button_add : @button_find).sensitive = ok
        end

        def on_find
            begin
                @results = Alexandria::BookProviders.title_search(@entry_title.text.strip)
                if @results.empty?
                    raise _("No results were found.  Make sure all words are spelled correctly, and try again.")
                else
                    @treeview_results.model.clear
                    @results.each do |book, small_cover, medium_cover|
                        iter = @treeview_results.model.append
                        iter[0] = _("%s, by %s") % [ book.title, book.authors.join(', ') ]
                        iter[1] = book.isbn
                    end
                end
            rescue => e
                ErrorDialog.new(@parent, 
                                _("Unable to find matches for your search"),
                                e.message)
            end
            @button_add.sensitive = false
        end

        def on_results_button_press_event(widget, event)
            # double left click
            if event.event_type == Gdk::Event::BUTTON2_PRESS and
               event.button == 1 

                on_add
            end
        end

        def on_add
            begin
                library = @libraries.find { |x| x.name == @combo_libraries.entry.text }
                
                if @isbn_radiobutton.active?
                    # Perform the ISBN search via the providers.
                    isbn = @entry_isbn.text.delete('-')
                    assert_not_exist(library, isbn)
                    book, small_cover, medium_cover = Alexandria::BookProviders.isbn_search(isbn)
                else
                    book, small_cover, medium_cover = selected_result
                    assert_not_exist(library, book.isbn)
                end 

                # Save the book in the library.
                library.save(book, small_cover, medium_cover)
                
                # Now we can destroy the dialog and go back to the main application.
                @new_book_dialog.destroy
                @block.call(book, library)
            rescue => e
                ErrorDialog.new(@parent, _("Couldn't add the book"), e.message)
            end
        end
    
        def on_cancel
            @new_book_dialog.destroy
        end
       
        def on_focus
            if @isbn_radiobutton.active? and @entry_isbn.text.strip.empty?
                text = Gtk::Clipboard.get(Gdk::Selection::CLIPBOARD).wait_for_text
                @entry_isbn.text = text if Library.valid_isbn?(text)
            end
        end
 
        #######
        private
        #######

        def selected_result
            @results.find do |book, small_cover, medium_cover|
                 book.isbn == @treeview_results.selection.selected[1]
            end
        end

        def assert_not_exist(library, isbn)
            # Check that the book doesn't already exist in the library.
            if book = library.find { |book| book.isbn == isbn }
                raise _("'%s' already exists in '%s' (titled '%s').") % [ book.isbn, library.name, book.title ] 
            end
        end

    end
end
end
