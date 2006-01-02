# Copyright (C) 2005-2006 Laurent Sansonetti
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

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        attr_reader :library

        ICON_WIDTH, ICON_HEIGHT = 70, 130
        PASTEBOARD_TYPE = :BooksPBoardType

        def flushCachedInfoForBook(book)
            @smallCovers.delete(book.ident) if @smallCovers
            @iconCovers.delete(book.ident) if @iconCovers
        end
        
        def library=(library)
            @library = library
            @tableViewLibrary = nil
            @matrixLibrary = nil
        end

        # NSTableView datasource

        def numberOfRowsInTableView(tableView)
            @library != nil ? @library.length : 0
        end
        
        def tableView_objectValueForTableColumn_row(tableView, col, row)
            @tableViewLibrary ||= _sortedLibraryForTableView(tableView)
            book = @tableViewLibrary[row]
            case col.identifier.to_s
                when 'title'
                    [ book.title.to_utf8_nsstring, _smallCoverForBook(book) ]
                when 'authors'
                    book.authors.join(', ').to_utf8_nsstring
                when 'isbn'
                    book.isbn
                when 'publisher'
                    book.publisher.to_utf8_nsstring
                when 'binding'
                    book.edition.to_utf8_nsstring
                when 'rating'
                    rating = (book.rating or Book::DEFAULT_RATING)
                    NSNumber.numberWithUnsignedInt(rating)
            end
        end
        
        def tableView_bookAtRow(tableView, row)
            @tableViewLibrary[row]
        end
        
        def tableView_setObjectValue_forTableColumn_row(tableView, objectValue, col, row)
            @tableViewLibrary ||= _sortedLibraryForTableView(tableView)
            book = @tableViewLibrary[row]
            case col.identifier.to_s
                when 'rating'
                    book.rating = objectValue.unsignedIntValue
                    @library.save(book)
            end
        end

        def tableView_writeRowsWithIndexes_toPasteboard(tableView, rowIndexes, pasteboard)
            books = []
            pos = rowIndexes.firstIndex
            while pos != NSNotFound
                books << @library[pos]
                pos = rowIndexes.indexGreaterThanIndex(pos)
            end
            return nil if books.empty?
            pasteboard.declareTypes_owner(NSArray.arrayWithObject(PASTEBOARD_TYPE),
                                          self)
            booksIdent = books.map { |book| book.ident }
            pasteboard.setPropertyList_forType(booksIdent, PASTEBOARD_TYPE)
            return true
        end

        def tableView_sortDescriptorsDidChange(tableView, oldDescriptors)
            @tableViewLibrary = nil
            tableView.reloadData
        end

        # NSMatrix datasource

        def numberOfCellsInMatrix(matrix)
            @library != nil ? @library.length : 0
        end
        
        def matrix_bookForColumn_row(matrix, col, row)
            pos = (matrix.numberOfColumns * row) + col
            @matrixLibrary ||= _sortedLibraryForMatrix(matrix)
            @matrixLibrary[pos]
        end
                                
        def matrix_objectValueForColumn_row(matrix, col, row)
            book = matrix_bookForColumn_row(matrix, col, row)
            [ _iconCoverForBook(book), book.title.to_utf8_nsstring ]
        end
        
        def matrix_tooltipForColumn_row(matrix, col, row)
            book = matrix_bookForColumn_row(matrix, col, row)
            if book.authors.empty?
                book.title
            else
                _("%s, by %s") % [ book.title.to_utf8_nsstring, 
                                   book.authors.join(', ').to_utf8_nsstring ]
            end
        end
        
        def pasteboardTypeForMatrix(matrix)
            PASTEBOARD_TYPE
        end
        
        def matrix_pasteboardStringForColumn_row(matrix, col, row)
            book = matrix_bookForColumn_row(matrix, col, row)
            book.ident
        end

        def matrix_sortDescriptorDidChange(matrix, oldDescriptor)
            @matrixLibrary = nil
            matrix.reloadData
        end

        #######
        private
        #######
        
        def _smallCoverForBook(book)
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
        
        def _iconCoverForBook(book)
            @iconCovers ||= {}
            cover = @iconCovers[book.ident]
            return cover if cover

            filename = @library.cover(book)
            @iconCovers[book.ident] = if File.exists?(filename)
                cover = NSImage.alloc.initWithContentsOfFile(filename)
                width, height = cover.size.to_a
                new_height = ICON_HEIGHT - 40
                new_width = [(width / (height / new_height)).ceil, ICON_WIDTH].min
                small_cover = NSImage.alloc.initWithSize(NSSize.new(ICON_WIDTH, new_height))
                drawRect = NSRect.new((ICON_WIDTH - new_width) / 2, 0, new_width, new_height)
                small_cover.lockFocus
                cover.drawInRect_fromRect_operation_fraction(drawRect,
                                                             NSRect.new(0, 0, width, height),
                                                             NSCompositeSourceOut,
                                                             1.0)
                NSColor.colorWithCalibratedWhite_alpha(0.8, 0.8).set
                NSFrameRect(drawRect)
                small_cover.unlockFocus
                small_cover
            else
                Icons::BOOK_ICON
            end
        end
        
        def _sortedLibraryForTableView(tableView)
            return nil if @library.nil?

            descriptors = tableView.sortDescriptors
            return @library if descriptors.count == 0
            _sortedLibraryWithSortDescriptor(descriptors.objectAtIndex(0))
        end
        
        def _sortedLibraryForMatrix(matrix)
            sortDescriptor = matrix.sortDescriptor
            sortDescriptor == nil ? @library : _sortedLibraryWithSortDescriptor(sortDescriptor)
        end
        
        def _sortedLibraryWithSortDescriptor(sortDescriptor)
            key = sortDescriptor.key.to_s
            sortedLibrary = @library.sort do |x, y| 
                a, b = x.send(key), y.send(key)
                if a == nil and b == nil
                    0
                elsif a == nil and b != nil
                    -1
                elsif a != nil and b == nil
                    1
                else
                    a <=> b
                end
            end
            sortedLibrary.reverse! if sortDescriptor.ascending?
            return sortedLibrary
        end
    end
end
end