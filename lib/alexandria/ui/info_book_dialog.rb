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
        include GetText
        extend GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent, library, book, &on_close_cb)
            super('info_book_dialog.glade')
            @info_book_dialog.transient_for = parent
            @on_close_cb = on_close_cb
            
            @image_cover.pixbuf = Icons.medium_cover(library, book)
            @entry_title.text = @info_book_dialog.title = book.title
            @entry_isbn.text = book.isbn
            @entry_publisher.text = book.publisher
            @entry_edition.text = book.edition
            
            @treeview_authors.model = Gtk::ListStore.new(String, TrueClass)
            @treeview_authors.selection.mode = Gtk::SELECTION_SINGLE
            renderer = Gtk::CellRendererText.new
            renderer.signal_connect('edited') do |cell, path_string, new_text|
                path = Gtk::TreePath.new(path_string)
                iter = @treeview_authors.model.get_iter(path)
                iter[0] = new_text 
            end
            col = Gtk::TreeViewColumn.new("", renderer, :text => 0, :editable => 1)
            @treeview_authors.append_column(col)
            book.authors.each do |author|
                iter = @treeview_authors.model.append
                iter[0] = author
                iter[1] = true
            end
        
            buffer = Gtk::TextBuffer.new
            buffer.text = (book.notes or "")
            @textview_notes.buffer = buffer
           
            @library, @book = library, book
            self.rating = (book.rating or Book::DEFAULT_RATING)
        end

        def on_add_author
            iter = @treeview_authors.model.append
            iter[0] = _("Author")
            iter[1] = true
            @treeview_authors.set_cursor(iter.path, 
                                         @treeview_authors.get_column(0), 
                                         true)
        end

        def on_remove_author
            if iter = @treeview_authors.selection.selected
	            @treeview_authors.model.remove(iter)
            end
        end
        
        def on_image_rating1_press
            self.rating = 1
        end
        
        def on_image_rating2_press
            self.rating = 2 
        end
        
        def on_image_rating3_press
            self.rating = 3 
        end
        
        def on_image_rating4_press
            self.rating = 4 
        end
        
        def on_image_rating5_press
            self.rating = 5 
        end
        
        def on_close
            @book.title = @entry_title.text
            @book.isbn = @entry_isbn.text
            @book.publisher = @entry_publisher.text
            @book.edition = @entry_edition.text
            @book.authors = []
            @treeview_authors.model.each { |m, p, i| @book.authors << i[0] }      
            @book.notes = @textview_notes.buffer.text 
            @book.rating = @current_rating
            
            @library.save(@book) 
            @on_close_cb.call
            @info_book_dialog.destroy
        end

        #######
        private
        #######
    
        def rating=(rating)
            images = [ 
                @image_rating1, 
                @image_rating2, 
                @image_rating3, 
                @image_rating4, 
                @image_rating5
            ]
            raise "out of range" if rating < 0 or rating > images.length
            images[0..rating-1].each { |x| x.pixbuf = Icons::STAR_SET }
            images[rating..-1].each { |x| x.pixbuf = Icons::STAR_UNSET }
            @current_rating = rating
        end
    end
end
end
