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
    class InfoBookDialog < GladeBase
        def initialize(parent, library, book)
            super('info_book_dialog.glade')
            @info_book_dialog.transient_for = parent
            @image_cover.file = library.medium_cover(book)
            @label_title.text = @info_book_dialog.title = book.title
            @label_authors.text = book.authors.join("\n")
            @label_isbn.text = book.isbn
            @label_publisher.text = book.publisher
            @label_edition.text = book.edition
            buffer = Gtk::TextBuffer.new
            buffer.text = (book.notes or "")
            @textview_notes.buffer = buffer
            @library, @book = library, book
        end

        def on_close
            new_notes = @textview_notes.buffer.text

            # Notes have changed: we need to re-save the book again.
            if @book.notes.nil? or (new_notes != @book.notes)
                @book.notes = new_notes
                @library.save(@book)
            end
            @info_book_dialog.destroy
        end
    end
end
end
