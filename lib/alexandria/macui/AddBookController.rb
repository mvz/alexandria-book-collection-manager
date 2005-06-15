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
    class AddBookController < OSX::NSObject
        include OSX

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        ib_outlets :window, :mainWindow, :resultsTableView, 
                   :librariesComboBox, :isbnButtonCell,
                   :searchButtonCell, :isbnTextField, :searchTextField,
                   :searchComboBox, :criterionMatrix, :addButton,
                   :progressIndicator, :resultsScrollView

        RESPONSE_ADD, RESPONSE_CANCEL = 1, 2

        def awakeFromNib
            @originalResultsSuperviewSize = @resultsTableView.superview.frame.size
            
            @resultsTableView.tableColumns.objectAtIndex(0).setResizingMask(1) # NSTableColumnAutoresizingMask
            @resultsTableView.setTarget(self)
            @resultsTableView.setDoubleAction(:onDoubleClickOnResults_)

            @results = []
            @resultsDirty = true
            _reloadResults
            @criterionMatrix.sendAction
        end
        
        def openWindow(selectedLibrary, &addBlock)
            app = NSApplication.sharedApplication
            @addBlock = addBlock

            @librariesComboBox.reloadData
            max = @librariesComboBox.numberOfItems
            max = 5 if max > 5
            @librariesComboBox.setNumberOfVisibleItems(max)
            
            index = @librariesComboBox.dataSource.libraries.index(selectedLibrary)
            index ||= 0
            @librariesComboBox.selectItemAtIndex(index)
            
            @searchComboBox.selectItemAtIndex(0)
            
            unless _isbnCriterion?
                @addButton.setEnabled(!@results.empty?)
            end

            app.beginSheet(@window, :modalForWindow, @mainWindow,
                                    :modalDelegate, self,
                                    :didEndSelector, :sheetDidEnd_returnCode_contextInfo_,
                                    :contextInfo, nil)
        end
        
        def opened?
            @window.isVisible?
        end
        
        def onAdd(sender)
            @books_to_add = []
            if _isbnCriterion?
                _asyncSearch(Library.canonicalise_isbn(@isbnTextField.stringValue.to_s),
                             BookProviders::SEARCH_BY_ISBN) do |result|
                    @books_to_add << result
                end
            else
                selection = @resultsTableView.selectedRowIndexes
                return if selection.count == 0
                index = selection.firstIndex
                begin
                    @books_to_add << @results[index]
                    index = selection.indexGreaterThanIndex(index)
                end while index != NSNotFound
            end
            
            unless @books_to_add.empty?
                NSApplication.sharedApplication.endSheet_returnCode(@window, RESPONSE_ADD)
            end
        end
        
        def onCancel(sender)
            NSApplication.sharedApplication.endSheet_returnCode(@window, RESPONSE_CANCEL)
        end

        def onDoubleClickOnResults(sender)
            NSApplication.sharedApplication.endSheet_returnCode(@window, RESPONSE_ADD)
        end
        
        def onToggleCriterion(sender)
            isbn = _isbnCriterion?
            @isbnTextField.setEnabled(isbn)
            @searchComboBox.setEnabled(!isbn)
            @searchTextField.setEnabled(!isbn)
            if @results.length > 0
                isbn ? _packResults : _unpackResults
            end
            
            if isbn
                _sensitizeAddButtonWithISBN(@isbnTextField.stringValue.to_s)
            else
                @addButton.setEnabled(@results.length > 0 &&
                                      @resultsTableView.selectedRow != -1)
            end
        end
        
        def numberOfRowsInTableView(tableView)
            @results != nil ? @results.length : 0
        end
        
        def tableView_objectValueForTableColumn_row(tableView, col, row)
            book = @results[row].first
            line = "#{book.title}"
            unless book.authors.empty?
                line << ", by #{book.authors.join(', ')}"
            end
            return line
        end
        
        def sheetDidEnd_returnCode_contextInfo(sheetWindow, returnCode, contextInfo)
            if returnCode == RESPONSE_ADD                
                sel = @librariesComboBox.indexOfSelectedItem
                return if sel == -1
                library = @librariesComboBox.dataSource.libraries[sel]

                @progressIndicator.setHidden(false)
                @progressIndicator.startAnimation(self)

                thread = Thread.start do
                    @books_to_add.each do |book, cover_uri|
                        unless cover_uri.nil?
                            library.save_cover(book, cover_uri)
                        end
                        library << book
                        library.save(book)
                    end
                end
                
                while thread.alive?
                    NSRunLoop.currentRunLoop.runUntilDate(NSDate.distantPast)
                end

                @progressIndicator.setHidden(true)
                @progressIndicator.stopAnimation(self)

                s = true
                @addBlock.call(library, @books_to_add.reject { s = !s })
            end
            sheetWindow.orderOut(self)
        end
        
        def controlTextDidChange(notification)
            textField = notification.object
            text = textField.stringValue.to_s
            if textField.__ocid__ == @isbnTextField.__ocid__
                _sensitizeAddButtonWithISBN(text)
            elsif textField.__ocid__ == @searchTextField.__ocid__
                @resultsDirty = true
            end
        end
        
        def controlTextDidEndEditing(notification)
            textField = notification.object
            if textField.__ocid__ == @searchTextField.__ocid__
                if @resultsDirty
                    _searchForResults
                    @resultsDirty = false
                end
            end
        end
        
        def windowDidBecomeKey(notification)
            if _isbnCriterion?
                pboard = NSPasteboard.generalPasteboard
                if pboard.types.containsObject?(:NSStringPboardType)
                    text = pboard.stringForType(:NSStringPboardType).to_s
                    _sensitizeAddButtonWithISBN(text, true)
                else
                    @addButton.setEnabled(false)
                end
            end
        end
        
        def _sensitizeAddButtonWithISBN(text, insertIntoISBNTextField=false)
            begin
                Library.canonicalise_isbn(text)
                if insertIntoISBNTextField
                    @isbnTextField.setStringValue(text)
                end
                @addButton.setEnabled(true)
            rescue Alexandria::Library::InvalidISBNError
                @addButton.setEnabled(false)
            end
        end
        
        def _packResults
            unless @resultsScrollView.superview.nil?
                @resultsScrollView.removeFromSuperview    
                newWindowFrame = @window.frame
                newWindowFrame.size.height -= @originalResultsSuperviewSize.height
                newWindowFrame.origin.y += @originalResultsSuperviewSize.height
                @window.setFrame(newWindowFrame, :display, true, :animate, true)
            end
        end
        
        def _unpackResults
            if @resultsScrollView.superview.nil?                
                newWindowFrame = @window.frame
                newWindowFrame.size.height += @originalResultsSuperviewSize.height
                newWindowFrame.origin.y -= @originalResultsSuperviewSize.height
                @window.setFrame(newWindowFrame, :display, true, :animate, true)
                @window.contentView.addSubview(@resultsScrollView)
            end
        end
        
        def _reloadResults
            newWindowFrame = @window.frame
            if @results.length == 0
                _packResults
            else
                _unpackResults
            end
            
            @resultsTableView.reloadData
        end

        def _asyncSearch(criterion, mode)
            @progressIndicator.setHidden(false)
            @progressIndicator.startAnimation(self)

            queue = ExecutionQueue.new

            do_reload_results = proc { |results| yield results }
            
            do_error = proc do |errorMessage|
                alert = NSAlert.alloc.init
                alert.setMessageText(_("Could not add the book"))
                alert.setInformativeText(errorMessage)
                alert.addButtonWithTitle(_("OK"))

                alert.beginSheetModalForWindow(@window, :modalDelegate, nil,
                                                        :didEndSelector, nil,
                                                        :contextInfo, nil)                
            end
            
            do_stop_progress = proc do
                @progressIndicator.stopAnimation(self)
                @progressIndicator.setHidden(true)
            end

            thread = Thread.start do
                begin
                    results = Alexandria::BookProviders.search(criterion, mode)
                    queue.sync_call(do_reload_results, results)
                rescue => e
                    queue.sync_call(do_error, e.message)
                ensure
                    queue.sync_call(do_stop_progress)
                end
            end
            
            while thread.alive?
                queue.iterate
                NSRunLoop.currentRunLoop.runUntilDate(NSDate.distantPast)
            end
            
            p 'okay'
        end

        def _searchForResults
            text = @searchTextField.stringValue.to_s.strip
            return if text.length == 0

            @searchComboBox.indexOfSelectedItem
            mode = case @searchComboBox.indexOfSelectedItem
                when 0
                    BookProviders::SEARCH_BY_TITLE
                when 1
                    BookProviders::SEARCH_BY_AUTHORS
                when 2
                    BookProviders::SEARCH_BY_KEYWORD
                else
                    BookProviders::SEARCH_BY_TITLE
            end

            _asyncSearch(text, mode) do |results|
                @results = results
                _reloadResults
                @addButton.setEnabled(!@results.empty?)
            end
        end
        
        def _stopAnimation(sender)
            @progressIndicator.stopAnimation(self)
            @progressIndicator.setHidden(true)
        end

        def _isbnCriterion?
            @criterionMatrix.selectedRow == 0
        end
    end
end
end