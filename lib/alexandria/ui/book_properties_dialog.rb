# Copyright (C) 2004-2005 Laurent Sansonetti
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
    class BookPropertiesDialog < BookPropertiesDialogBase
        include GetText
        extend GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent, library, book, &on_close_cb)
            super(parent, library.cover(book))
            @on_close_cb = on_close_cb
           
            close_button = Gtk::Button.new(Gtk::Stock::CLOSE)
            close_button.signal_connect('pressed') { on_close }
            close_button.show
            @button_box << close_button
            
            @entry_title.text = @book_properties_dialog.title = book.title
            @entry_isbn.text = book.isbn
            @entry_publisher.text = book.publisher
            @entry_edition.text = book.edition
            
            book.authors.each do |author|
                iter = @treeview_authors.model.append
                iter[0] = author
                iter[1] = true
            end
        
            buffer = Gtk::TextBuffer.new
            buffer.text = (book.notes or "")
            @textview_notes.buffer = buffer
           
            @library, @book = library, book
            self.cover = Icons.cover(library, book)
            self.rating = (book.rating or Book::DEFAULT_RATING)
            
            if @checkbutton_loaned.active = book.loaned?
                @entry_loaned_to.text = (book.loaned_to or "")
                self.loaned_since = (book.loaned_since or Time.now.tv_sec)
            end
        end

        def on_destroy; on_close; end
        
        #######
        private
        #######
        
        def on_close
            @book.title = @entry_title.text
            new_isbn = begin
                Library.canonicalise_isbn(@entry_isbn.text)
            rescue
                ErrorDialog.new(@parent, 
                                _("Couldn't modify the book"), 
                                _("Couldn't validate the EAN/ISBN you " +
                                  "provided.  Make sure it is written " +
                                  "correcty, and try again."))
                return
            end
            @book.publisher = @entry_publisher.text
            @book.edition = @entry_edition.text
            @book.authors = []
            @treeview_authors.model.each { |m, p, i| @book.authors << i[0] }      
            @book.notes = @textview_notes.buffer.text 
            @book.rating = @current_rating
           
            @book.loaned = @checkbutton_loaned.active?
            @book.loaned_to = @entry_loaned_to.text
            @book.loaned_since = @date_loaned_since.time
           
            @library.save(@book, new_isbn) 
            @on_close_cb.call(@book)
            @book_properties_dialog.destroy
        end
    end
end
end
