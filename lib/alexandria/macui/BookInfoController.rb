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

require 'fileutils'

module Alexandria
module UI
    class BookInfoController < OSX::NSObject
        include OSX

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        ib_outlets :titleTextField, :isbnTextField, :authorsTableView,
                   :publisherTextField, :bindingTextField,
                   :coverImageView, :panel, :loanedToTextField,
                   :loanedSinceDatePicker, :loanedSwitchButton,
                   :tabView, :ratingField, :addAuthorButton,
                   :removeAuthorButton, :notesTextView,
                   :buttonsView, :infoButtonsView, :addButtonsView,
                   :previousButton, :nextButton
        
        def awakeFromNib
            @coverImageView.setImageFrameStyle(NSImageFramePhoto)
            @addAuthorButton.setImage(Icons::MORE)
            @removeAuthorButton.setImage(Icons::LESS)
            @ratingField.setDelegate(self)
            @authorsTableView.setDoubleAction(:doubleClickOnAuthors)
            @authorsTableView.setTarget(self)
            @coverImageView.setAction(:coverDidChange)
            @coverImageView.setTarget(self)
            @loanedSinceDatePicker.setMaxDate(NSDate.date)

            @booksToSave = []
        end
        
        EDIT_WINDOW, MANUAL_ADD_WINDOW = 1, 2
                
        def openWindowToEdit(library, book, &on_close_block)
            @type = EDIT_WINDOW
            @book, @library, @on_close_block = book, library, on_close_block
            @booksToSave.clear
            _updateUI
            @tabView.selectTabViewItemAtIndex(0)
            @buttonsView.subviews.to_a.each { |x| x.removeFromSuperviewWithoutNeedingDisplay }
            @buttonsView.addSubview(@infoButtonsView)
            @infoButtonsView.setFrame(@buttonsView.bounds)
            NSApplication.sharedApplication.runModalForWindow(@panel)
        end
        
        def openWindowToAdd(library, &on_close_block)
            @type = MANUAL_ADD_WINDOW
            @library, @on_close_block = library, on_close_block
            @book = Book.new('', [], nil, '', '')
            _updateUI
            @tabView.selectTabViewItemAtIndex(0)
            @buttonsView.subviews.to_a.each { |x| x.removeFromSuperviewWithoutNeedingDisplay }
            @buttonsView.addSubview(@addButtonsView)
            @addButtonsView.setFrame(@buttonsView.bounds)
            NSApplication.sharedApplication.runModalForWindow(@panel)
        end

        # Actions
        
        def add(sender)
            _validateEditing
            unless _alertRunning?
                if @book.title.empty?
                    _alert(_("Couldn't add the book"),
                           _("A title must be provided."),
                           @titleTextField)
                elsif @book.publisher.empty?
                    _alert(_("Couldn't add the book"),
                           _("A publisher must be provided."))
                elsif @book.edition.empty?
                    _alert(_("Couldn't add the book"),
                           _("A binding must be provided."))
                elsif @book.authors.empty?
                    _alert(_("Couldn't add the book"),
                           _("At least one author must be provided."))
                else
                    @book.saved_ident = @book.ident
                    @library.save_cover(@book, @coverFilename) if @coverFilename
                    @library << @book
                    @library.save(@book)
                    @on_close_block.call(@book)
                    @panel.close
                end
            end
        end
        
        def addAuthor(sender)
            @book.authors << _("Author")
            @authorsTableView.reloadData
            row = @book.authors.length - 1
            @authorsTableView.selectRowIndexes_byExtendingSelection(NSIndexSet.indexSetWithIndex(row),
                                                                    false)
            @authorsTableView.editColumn(0, :row, row,
                                            :withEvent, nil,
                                            :select, true)
        end
        
        def removeAuthor(sender)
            row = @authorsTableView.selectedRow
            return if row == -1
            @book.authors.delete_at(row)
            @authorsTableView.reloadData
        end
        
        def doubleClickOnAuthors
            row = @authorsTableView.selectedRow
            return if row == -1
            @authorsTableView.editColumn(0, :row, row,
                                            :withEvent, nil,
                                            :select, true)
        end

        def toggleLoaned(sender)
            isLoaned = sender.state == NSOnState
            @book.loaned = isLoaned
            @loanedToTextField.setEnabled(isLoaned)
            @loanedSinceDatePicker.setEnabled(isLoaned)
            _scheduleSave if @type == EDIT_WINDOW
        end
        
        def previousBook(sender)
            _validateEditing
            index = @library.index(@book)
            index = if index == 0
                @library.length - 1
            else
                index - 1
            end
            @book = @library[index]
            _updateUI
        end
        
        def nextBook(sender)
            _validateEditing
            index = @library.index(@book)
            index = if index == @library.length - 1
                0
            else
                index + 1
            end
            @book = @library[index]
            _updateUI
        end

        def coverDidChange(sender)
            newImage = @coverImageView.image
            if newImage
                newBitmap = NSBitmapImageRep.imageRepWithData(newImage.TIFFRepresentation)
                properties = NSDictionary.dictionaryWithObject_forKey(NSNumber.numberWithFloat(1),
                                                                      'NSImageCompressionFactor')
                jpegData = newBitmap.representationUsingType_properties(NSJPEGFileType,
                                                                        properties)
                @coverFilename = @type == EDIT_WINDOW \
                    ? @library.cover(@book) \
                    : File.join(OSX::NSTemporaryDirectory(), 'cover.jpg')
                jpegData.writeToFile_atomically(@coverFilename, true)
            else
                @coverImageView.setImage(Icons::NO_COVER)
                FileUtils.rm_f(@library.cover(@book))
            end
            _scheduleSave if @type == EDIT_WINDOW
        end

        # NSWindow delegation
        
        def windowShouldClose(sender)
            if @panel.isVisible?
                if @type == EDIT_WINDOW
                    _validateEditing
                    return false if _alertRunning?                
                    @booksToSave.each { |book| @library.save(book) }
                    @on_close_block.call(@booksToSave)
                end
            end
            return true
        end
        
        def windowWillClose(notification)
            NSApplication.sharedApplication.stopModal
        end
        
        # NSTextField delegation

        def controlTextDidChange(notification)
            textView = notification.object
            string = textView.stringValue.UTF8String.strip
            if textView.__ocid__ == @titleTextField.__ocid__
                @panel.setTitle(string)
            end
        end
        
        def control_textShouldEndEditing(control, text)
            string = control.stringValue.to_s.strip
            if control.__ocid__ == @isbnTextField.__ocid__
                unless string.empty?
                    ary = @library.select { |book| book.ident == string }
                    unless ary.empty? or (ary.length == 1 and ary.first == @book)
                        _alert(_("Couldn't modify the book"),
                               _("The EAN/ISBN you provided is already " +
                                 "used in this library."))
                        return false
                    end                   
                    newIsbn = begin
                        Library.canonicalise_isbn(string)
                    rescue Alexandria::Library::InvalidISBNError
                        _alert(_("Couldn't modify the book"),
                               _("Couldn't validate the EAN/ISBN you " +
                                 "provided.  Make sure it is written " +
                                 "correcty, and try again."))
                        return false
                    end
                    @isbnTextField.setStringValue(newIsbn)
                end
            end
            return true
        end

        def controlTextDidEndEditing(notification)
            textView = notification.object
            string = textView.stringValue.UTF8String.strip
            changed = false
            if textView.__ocid__ == @titleTextField.__ocid__
                if @book.title != string
                    changed = true
                    @book.title = string
                end
            elsif textView.__ocid__ == @isbnTextField.__ocid__
                newIsbn = string == "" ? nil : Library.canonicalise_isbn(string)
                if @book.isbn != newIsbn
                    changed = true
                    @book.isbn = newIsbn
                end
            elsif textView.__ocid__ == @publisherTextField.__ocid__
                if @book.publisher != string
                    changed = true
                    @book.publisher = string
                end
            elsif textView.__ocid__ == @bindingTextField.__ocid__
                if @book.edition != string
                    changed = true
                    @book.edition = string
                end
            elsif textView.__ocid__ == @loanedToTextField.__ocid__
                if @book.loaned_to != string
                    changed = true
                    @book.loaned_to = string
                end
            end
            _scheduleSave if changed and @type == EDIT_WINDOW
        end

        # RatingField delegation
        
        def ratingField_ratingDidChange(ratingField, newRating)
            if @book.rating != newRating
                @book.rating = newRating
                _scheduleSave if @type == EDIT_WINDOW
            end
        end

        # NSTableView delegation

        def tableViewSelectionDidChange(notification)
            _sensitizeAuthors
        end

        def tableView_deleteCharacterDown(tableView)
            removeAuthor(self)
        end

        # NSTableView data source
        
        def numberOfRowsInTableView(tableView)
            @book != nil ? @book.authors.length : 0
        end
        
        def tableView_objectValueForTableColumn_row(tableView, col, row)
            @book.authors[row].to_utf8_nsstring
        end

        def tableView_setObjectValue_forTableColumn_row(tableView, objectValue, col, row)
            author = @book.authors[row]
            newAuthor = objectValue.UTF8String.strip
            if author != newAuthor
                @book.authors[row] = newAuthor
                _scheduleSave if @type == EDIT_WINDOW 
            end
        end

        #######
        private
        #######
        
        def _updateUI
            @panel.setTitle(@book.title.to_utf8_nsstring)
        
            @titleTextField.setStringValue(@book.title.to_utf8_nsstring)
            @isbnTextField.setStringValue((@book.isbn or ""))
            @publisherTextField.setStringValue(@book.publisher.to_utf8_nsstring)
            @bindingTextField.setStringValue(@book.edition.to_utf8_nsstring)
    
            @authorsTableView.reloadData
            _sensitizeAuthors
            
            filename = @library.cover(@book)
            cover = if File.exists?(filename)
                NSImage.alloc.initWithContentsOfFile(filename)
            else
                Icons::NO_COVER
            end
            @coverImageView.setImage(cover)
            
            rating = (@book.rating or Book::DEFAULT_RATING)
            @ratingField.setObjectValue(NSNumber.numberWithUnsignedInt(rating))
            
            if @book.loaned?
                @loanedSwitchButton.setState(NSOnState)
                @loanedToTextField.setEnabled(true)
                @loanedSinceDatePicker.setEnabled(true)
            else
                @loanedSwitchButton.setState(NSOffState)
                @loanedToTextField.setEnabled(false)
                @loanedSinceDatePicker.setEnabled(false)
            end
            
            @loanedToTextField.setStringValue((@book.loaned_to or "").to_utf8_nsstring)
            date = if @book.loaned_since != nil
                NSDate.dateWithTimeIntervalSince1970(@book.loaned_since)
            else
                NSDate.date
            end
            @loanedSinceDatePicker.setDateValue(date)

            @notesTextView.setString((@book.notes or "").to_utf8_nsstring)
        
            canBrowse = @library.length > 1
            @previousButton.setEnabled(canBrowse)
            @nextButton.setEnabled(canBrowse)
        end
        
        def _alertRunning?
            @alertRunning
        end
        
        def _alertDidEnd(sender)
            @alertRunning = false
            
            if @panel.firstResponder.__ocid__ == @panel.__ocid__
                @panel.makeFirstResponder(@alertFirstResponder)
                # Ugly hack to force editing...
                @alertFirstResponder.currentEditor.copy(self)
                @alertFirstResponder.currentEditor.paste(self)
            end
        end
        
        def _alert(title, description, responder=nil)
            alert = NSAlert.alloc.init
            alert.setMessageText(title)
            alert.setInformativeText(description)
            alert.addButtonWithTitle(_("OK"))

            @alertRunning = true
            @alertFirstResponder = (responder or @isbnTextField)
            alert.beginSheetModalForWindow(@panel, :modalDelegate, self,
                                                   :didEndSelector, :_alertDidEnd_,
                                                   :contextInfo, nil)
        end
        
        def _validateEditing
            responder = @panel.firstResponder
            if responder != nil and responder.is_a?(NSTextView)
                [@titleTextField, @isbnTextField, 
                 @authorsTableView, @publisherTextField, 
                 @bindingTextField, @loanedToTextField].each do |control| 
                    editor = control.currentEditor
                    if editor != nil and editor.__ocid__ == responder.__ocid__
                        control.selectedCell.endEditing(responder)
                        break
                    end
                end
            end

            # handle the notes...
            newNotes = @notesTextView.string.UTF8String.strip
            if @book.notes != newNotes
                @book.notes = newNotes
                _scheduleSave if @type == EDIT_WINDOW
            end
            
            # handle the loaning date...
            newLoaningDate = @loanedSinceDatePicker.dateValue.timeIntervalSince1970
            if @book.loaned_since != newLoaningDate
                @book.loaned_since = newLoaningDate
                _scheduleSave if @type == EDIT_WINDOW
            end
        end

        def _sensitizeAuthors
            @removeAuthorButton.setEnabled(@book.authors.length > 0 &&
                                           @authorsTableView.selectedRow != -1)
        end

        def _scheduleSave
            return if @booksToSave.include?(@book)
            @booksToSave << @book
        end
    end
end
end