# Copyright (C) 2005 Laurent Sansonetti
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
    class BooksDataSource < OSX::NSObject
        include OSX
        
        attr_accessor :library
        
        def numberOfRowsInTableView(tableView)
            @library != nil ? @library.length : 0
        end
        
        def tableView_objectValueForTableColumn_row(tableView, col, row)
            book = @library[row]
            case col.identifier.to_s
                when 'title'
                    [ book.title, _coverForBook(book) ]
                when 'authors'
                    book.authors.join(', ')
                when 'isbn'
                    book.isbn
                when 'publisher'
                    book.publisher
                when 'binding'
                    book.edition
                when 'rating'
                    rating = (book.rating or Book::DEFAULT_RATING)
                    NSNumber.numberWithUnsignedInt(rating)
            end
        end
        
        def tableView_setObjectValue_forTableColumn_row(tableView, objectValue, col, row)
            book = @library[row]
            case col.identifier.to_s
                when 'rating'
                    book.rating = objectValue.unsignedIntValue
                    @library.save(book)
            end
        end
        
        def _coverForBook(book)
            @covers ||= {}
            cover = @covers[book.ident]
            return cover if cover

            filename = @library.cover(book)
            @covers[book.ident] = if File.exists?(filename)
                cover = NSImage.alloc.initWithContentsOfFile(filename)
                width, length = cover.size.to_a
                new_height = 19
                new_width = (width / (length / new_height)).ceil
                small_cover = NSImage.alloc.initWithSize(NSSize.new(19, new_height))
                small_cover.lockFocus
                cover.drawInRect_fromRect_operation_fraction(NSRect.new((19 - new_width) / 2.0, 
                                                                        0, new_width, new_height),
                                                             NSRect.new(0, 0, width, length),
                                                             NSCompositeSourceOut,
                                                             1.0)
                small_cover.unlockFocus
                small_cover
            else
                Icons::BOOK_SMALL
            end
        end
    end
end
end