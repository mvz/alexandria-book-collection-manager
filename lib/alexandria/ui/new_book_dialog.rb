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
        end
    
        def on_changed(entry)
            raise unless entry.is_a?(Gtk::Entry)
            @button_find.sensitive = !entry.text.strip.empty?
        end
    
        def on_add
            begin
                # First check that the book doesn't already exist in the library.
                library = @libraries.find { |x| x.name == @combo_libraries.entry.text }
                if book = library.find { |book| book.isbn == @entry_isbn.text }
                    raise "'#{book.isbn}' already exists in '#{library.name}' (titled '#{book.title}')."
                end

                # Perform the search via the providers.
                book, small_cover, medium_cover = Alexandria::BookProviders.search(@entry_isbn.text)

                # Save the book in the library.
                library.save(book, small_cover, medium_cover)
                
                # Now we can destroy the dialog and go back to the main application.
                @new_book_dialog.destroy
                @block.call(book, library)
            rescue Errno::EINVAL
                # For a strange reason it seems that the first request always fails
                # on FreeBSD.
                retry
            rescue => e
                ErrorDialog.new(@parent, "Couldn't add book", e.message)
            end
        end
    
        def on_cancel
            @new_book_dialog.destroy
        end
    end
end
end
