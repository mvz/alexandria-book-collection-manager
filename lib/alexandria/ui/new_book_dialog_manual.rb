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
    class NewBookDialogManual < BookPropertiesDialogBase
        include GetText
        extend GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        TMP_COVER_FILE = File.join(Dir.tmpdir, "tmp_cover")
        def initialize(parent, library, &on_add_cb)
            super(parent, TMP_COVER_FILE)

            @library, @on_add_cb = library, on_add_cb
            FileUtils.rm_f(TMP_COVER_FILE)
            
            cancel_button = Gtk::Button.new(Gtk::Stock::CANCEL)
            cancel_button.signal_connect('pressed') { on_cancel }
            cancel_button.show
            @button_box << cancel_button
            
            add_button = Gtk::Button.new(Gtk::Stock::ADD)
            add_button.signal_connect('pressed') { on_add }
            add_button.show
            @button_box << add_button
            
            self.rating = Book::DEFAULT_RATING
            self.cover = Icons::BOOK
        end

        #######
        private
        #######

        def on_cancel
            @book_properties_dialog.destroy
        end

        def on_add
            begin
                if (title = @entry_title.text.strip).empty?
                    raise _("A title must be provided.")
                end

                isbn = begin
                    Library.canonicalise_isbn(@entry_isbn.text)
                rescue Alexandria::Library::InvalidISBNError
                    unless @entry_isbn.text == ""
                        raise _("Couldn't validate the EAN/ISBN you " +
                                "provided.  Make sure it is written " +
                                "correcty, and try again.")
                    else
                        isbn = nil
                    end
                end
                    
                if (publisher = @entry_publisher.text.strip).empty?
                    raise ("A publisher must be provided.")
                end
                
                if (edition = @entry_edition.text.strip).empty?
                    raise ("A binding must be provided.")
                end
                
                authors = []
                @treeview_authors.model.each { |m, p, i| authors << i[0] }
                if authors.empty?
                    raise ("At least one author must be provided.") 
                end

                book = Book.new(title, authors, isbn, publisher, edition)
                book.rating = @current_rating
                book.notes = @textview_notes.buffer.text 
                book.loaned = @checkbutton_loaned.active?
                book.loaned_to = @entry_loaned_to.text
                book.loaned_since = @date_loaned_since.time

                @library.save(book)
                if File.exists?(TMP_COVER_FILE)
                    FileUtils.cp(TMP_COVER_FILE, @library.cover(book))
                end

                @on_add_cb.call(book)
                @book_properties_dialog.destroy
            rescue => e
                ErrorDialog.new(@parent, _("Couldn't add the book"),
                                e.message)
            end
        end
    end
end
end
