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
    class BookInfoController < OSX::NSObject
        include OSX

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        ib_outlets :drawer, :titleTextField, :coverImageView
        
        def awakeFromNib
            @titleTextField.setFocusRingType(NSFocusRingTypeNone)
        end
        
        def open
            @drawer.open
        end
        
        def close
            @drawer.close
        end
        
        def opened?
            @drawer.state == NSDrawerOpenState
        end
        
        def setSelectedBook_library(book, library)
            @book, @library = book, library
            _updateUI
        end
        
        # NSTextField delegation
        
        def control_textShouldBeginEditing(control, textEditor)
            p 'here'
            true
        end
        
        def textDidBeginEditing(notification)
            p 'begin'
        end
        
        def controlTextDidChange(notification)
            p 'changing'
        end

        #######
        private
        #######
        
        def _updateUI
            @titleTextField.setStringValue(@book.title)
            
            filename = @library.cover(@book)
            cover = if File.exists?(filename)
                NSImage.alloc.initWithContentsOfFile(filename)
            else
                Icons::BOOK
            end

            @coverImageView.setImage(cover)
        end
    end
end
end