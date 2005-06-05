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
    class MainController < OSX::NSObject
        include OSX

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        ib_outlets :mainWindow, :booksView, :booksTableView, 
                   :librariesTableView, :toolbarSearchView, 
                   :toolbarSwitchModeView, :librariesDataSource,
                   :addBookController, :toolbarSearchField,
                   :bookInfoController, :aboutController
        
        VIEW_AS_ICON, VIEW_AS_LIST = 0, 1
        
        def awakeFromNib
            _setupSearchField
            _setupLibrariesTableView
            _setupViews
            _setupToolbar
            _setBooksView(VIEW_AS_LIST)            
        end
        
        # NSWindow delegation
        
        def windowDidBecomeKey(notification)
            # FIXME: MainController should inherit of NSWindowController and we should
            # do the following in windowDidLoad.
            @windowLoaded ||= false
            unless @windowLoaded
                _selectLibrary(@librariesTableView.dataSource.libraries.first)
                @windowLoaded = true
            end
        end
        
        # NSToolbar delegation
        
        TOOLITEM_NEW, TOOLITEM_ADD, TOOLITEM_SEARCH, TOOLITEM_SWITCH_MODE = \
            (0..3).to_a.map { |x| x.to_s }
        
        def _setupToolbar
            toolbar = NSToolbar.alloc.initWithIdentifier('myToolbar')
            toolbar.setDisplayMode(NSToolbarDisplayModeIconAndLabel)
            toolbar.setDelegate(self)
            @mainWindow.setToolbar(toolbar)
            @toolbarItems = {}
            @mainWindow.toolbar.visibleItems.to_a.each do |toolItem|
                @toolbarItems[toolItem.itemIdentifier.to_s] = toolItem
            end
        end
    
        def _filterBooks(sender)
            criterion = @toolbarSearchField.stringValue.to_s.strip.downcase
            unless criterion.empty?
                filteredLibrary = _selectedLibrary.select do |book|
                    s = case @searchCategory
                        when FILTER_TITLES
                            book.title
                        when FILTER_AUTHORS
                            book.authors.join(', ')
                        when FILTER_ISBNS
                            book.isbn
                        when FILTER_PUBLISHERS
                            book.publisher
                        when FILTER_NOTES
                            (book.notes or "")
                        when FILTER_ALL
                            [book.title, book.authors.join(', '), book.isbn,
                             book.publisher, (book.notes or "")].join(' ')
                    end
                    s.downcase.include?(criterion)
                end
                label = "#{filteredLibrary.length} of #{_selectedLibrary.length}"
            else
                filteredLibrary = _selectedLibrary
                label = 'Search'
            end
            
            @toolbarItems[TOOLITEM_SEARCH].setLabel(label)
            @booksTableView.dataSource.library = filteredLibrary
            @booksTableView.reloadData
        end
        
        def toolbar_itemForItemIdentifier_willBeInsertedIntoToolbar(toolbar, identifier, flag)
            toolitem = NSToolbarItem.alloc.initWithItemIdentifier(identifier)
            case identifier.to_s
                when TOOLITEM_NEW
                    toolitem.setLabel('New Library')
                    toolitem.setImage(Icons::LIBRARY)
                    toolitem.setAction(:newLibrary)
                    toolitem.setTarget(self)
                when TOOLITEM_ADD
                    toolitem.setLabel('Add Book')
                    toolitem.setImage(Icons::BOOK)
                    toolitem.setAction(:addBook)
                    toolitem.setTarget(self)
                when TOOLITEM_SEARCH
                    toolitem.setLabel('Search')
                    toolitem.setView(@toolbarSearchView)
                    height = @toolbarSearchView.frame.size.height
                    toolitem.setMinSize(NSSize.new(150, height))
                when TOOLITEM_SWITCH_MODE
                    toolitem.setLabel('View As')
                    toolitem.setView(@toolbarSwitchModeView)
                    toolitem.setMinSize(@toolbarSwitchModeView.frame.size)
            end
            return toolitem.retain
        end
        
        def toolbarDefaultItemIdentifiers(toolbar)
            [TOOLITEM_NEW, 
             TOOLITEM_ADD, 
             OSX.NSToolbarFlexibleSpaceItemIdentifier,
             TOOLITEM_SEARCH,
             OSX.NSToolbarFlexibleSpaceItemIdentifier,
             TOOLITEM_SWITCH_MODE]
        end
        
        def toolbarAllowedItemIdentifiers(toolbar)
            toolbarDefaultItemIdentifiers(toolbar)
        end
        
        # NSTableView delegation
        
        def tableViewSelectionDidChange(notification)
            tableView = notification.object
            if tableView.__ocid__ == @librariesTableView.__ocid__
                _filterBooks(nil)
                @mainWindow.setTitle(_selectedLibrary.name)
            end
        end

        def tableView_shouldEditTableColumn_row(tableView, tableColumn, row)
            if tableView.__ocid__ == @librariesTableView.__ocid__
                true
            elsif tableView.__ocid__ == @booksTableView.__ocid__
                tableColumn.identifier.to_s != 'rating'
            end
        end

        def tableView_deleteCharacterDown(tableView)
            if tableView.__ocid__ == @librariesTableView.__ocid__
                _deleteSelectedLibrary
            elsif tableView.__ocid__ == @booksTableView.__ocid__
                _deleteSelectedBooks
            end
        end
        
        def tableView_mouseDown_oldSelectedRow(tableView, event, oldSelectedRow)
            if tableView.__ocid__ == @booksTableView.__ocid__
                point = tableView.convertPoint_fromView(event.locationInWindow, nil)
                row, col = tableView.rowAtPoint(point), tableView.columnAtPoint(point)
                return if row == -1 or col == -1
                return unless row == oldSelectedRow

                tableColumn = tableView.tableColumns.objectAtIndex(col)
                return unless tableColumn.identifier.to_s == 'rating'

                cellFrame = tableView.frameOfCellAtColumn_row(col, row)
                point.x -= cellFrame.origin.x
                point.y -= cellFrame.origin.y

                rating = RatingCell.valueForPoint(point)
                tableView.dataSource.tableView(tableView, :setObjectValue, NSNumber.numberWithUnsignedInt(rating),
                                                          :forTableColumn, tableColumn,
                                                          :row, row)
                tableView.reloadData
            end
        end

        # NSTextField delegation
        
        def controlTextDidChange(notification)
            view = notification.object
            if view.__ocid__ == @toolbarSearchField.__ocid__
                NSObject.cancelPreviousPerformRequestsWithTarget(self, :selector, :_filterBooks_,
                                                                       :object, nil)
                self.performSelector(:_filterBooks_, :withObject, nil,
                                                     :afterDelay, 0.5)
            end
        end

        # Completion

        def textView_completions_forPartialWordRange_indexOfSelectedItem(textView, words, charRange, index)
            p 'completion'
            return NSArray.array
        end

        # NSMenuItem validation

        def validateMenuItem(menuItem)
            case menuItem.action.to_s
                when 'getInfo:'
                    _focusOnBooksView? and _selectedBooks.length == 1

                when 'about:'
                    !@aboutController.opened?

                when 'delete:'
                    (_focusOnBooksView? and !_selectedBooks.empty?) or _focusOnLibraryView?

                else
                    true
            end
        end
        
        # Actions
        
        def about(sender)
            @aboutController.openWindow
        end
        
        def reportBug(sender)
            url = NSURL.URLWithString(BUGREPORT_URL)
            NSWorkspace.sharedWorkspace.openURL(url)
        end
        
        def makeDonation(sender)
            url = NSURL.URLWithString(DONATE_URL)
            NSWorkspace.sharedWorkspace.openURL(url)
        end
        
        def getInfo(sender)
            books = _selectedBooks
            return if books.length != 1
            dataSource = @booksTableView.dataSource
            @bookInfoController.openWindow(dataSource.library, 
                                           books.first) do |modifiedBooks|
                modifiedBooks.each do |book|
                    dataSource.flushCachedInfoForBook(book)
                end
                @booksTableView.reloadData
            end
        end
    
        def newLibrary(sender)
            library = @librariesDataSource.addLibraryWithAutogeneratedName
            @librariesTableView.reloadData
            _selectLibrary(library, true)
        end
        
        def addBook(sender)
            @addBookController.openWindow(_selectedLibrary) do |library, books|
                if _selectedLibrary != library
                    _selectLibrary(library)
                else
                    _filterBooks(nil)
                end
            end
        end

        def delete(sender)
            if _focusOnBooksView?
                _deleteSelectedBooks
            elsif _focusOnLibraryView?
                _deleteSelectedLibrary
            end 
        end
        
        def doubleClickOnLibraries(sender)
        end
        
        def doubleClickOnBooks(sender)
            getInfo(sender)
        end
    
        #######
        private
        #######
        
        def _selectedLibrary
            index = @librariesTableView.selectedRow
            index = 0 if index == -1
            @librariesTableView.dataSource.libraries[index]
        end
        
        def _selectedBooks
            books = []
            selection = @booksTableView.selectedRowIndexes
            library = @booksTableView.dataSource.library
            if selection.count > 0 and !library.empty?
                index = selection.firstIndex
                begin
                    books << library[index]
                    index = selection.indexGreaterThanIndex(index)
                end while index != NSNotFound
            end
            return books
        end

        def _selectLibrary(library, startEditing=false)
            libraries = @librariesTableView.dataSource.libraries
            pos = libraries.index(library)
            @librariesTableView.selectRowIndexes_byExtendingSelection(NSIndexSet.indexSetWithIndex(pos),
                                                                      false)
            if startEditing
                @librariesTableView.editColumn(0, :row, pos,
                                                  :withEvent, nil,
                                                  :select, true)
            end
        end

        def _deleteLibraryAlertDidEnd_returnCode_contextInfo(alert, returnCode, contextInfo)
            if returnCode == NSAlertFirstButtonReturn
                row = @librariesTableView.selectedRow
                @librariesTableView.dataSource.removeLibraryAtIndex(row)
                @librariesTableView.reloadData
            end
        end

        def _deleteBooksAlertDidEnd_returnCode_contextInfo(alert, returnCode, contextInfo)
            if returnCode == NSAlertFirstButtonReturn
                library = _selectedLibrary
                _selectedBooks.each { |book| library.delete(book) }
                _filterBooks(nil)
            end
        end

        def _deleteSelectedLibrary
            library = _selectedLibrary
            messageText = if library.length == 0
                _("Are you sure you want to permanently delete '%s'?") % library.name
            else
                n_("Are you sure you want to permanently delete '%s' " +
                   "which has %d book?",
                   "Are you sure you want to permanently delete '%s' " +
                   "which has %d books?", library.size) % [ library.name, library.size ]
            end

            alert = NSAlert.alloc.init
            alert.setMessageText(messageText)
            alert.setInformativeText(_("This operation cannot be undone."))
            alert.addButtonWithTitle(_("Delete"))
            alert.addButtonWithTitle(_("Cancel"))

            alert.beginSheetModalForWindow(@mainWindow, :modalDelegate, self,
                                                        :didEndSelector, :_deleteLibraryAlertDidEnd_returnCode_contextInfo_,
                                                        :contextInfo, nil)        
        end

        def _deleteSelectedBooks
            books_to_delete = _selectedBooks
            return if books_to_delete.empty?
            library = @booksTableView.dataSource.library

            messageText = if books_to_delete.length == 1
                _("Are you sure you want to permanently delete '%s' " +
                  "from '%s'?") % [ books_to_delete.first.title, library.name ]
            else
                _("Are you sure you want to permanently delete the " +
                  "selected books from '%s'?") % library.name
            end

            alert = NSAlert.alloc.init
            alert.setMessageText(messageText)
            alert.setInformativeText(_("This operation cannot be undone."))
            alert.addButtonWithTitle(_("Delete"))
            alert.addButtonWithTitle(_("Cancel"))

            alert.beginSheetModalForWindow(@mainWindow, :modalDelegate, self,
                                                        :didEndSelector, :_deleteBooksAlertDidEnd_returnCode_contextInfo_,
                                                        :contextInfo, nil)
        end

        FILTER_ALL, FILTER_TITLES, FILTER_AUTHORS, FILTER_ISBNS, FILTER_PUBLISHERS,
            FILTER_NOTES = (0..6).to_a.map { |x| x.to_s }
        
        def _updateSearchCategory(sender)
            sender.menu.itemArray.to_a.each do |menuItem|
                if sender.__ocid__ == menuItem.__ocid__
                    menuItem.setState(NSOnState)
                    @searchCategory = menuItem.representedObject.to_s
                else
                    menuItem.setState(NSOffState)
                end
            end
            _filterBooks(nil)
        end
    
        def _setupSearchField
            menu = NSMenu.alloc.initWithTitle('')
            [['All', FILTER_ALL],
             ['Titles', FILTER_TITLES],
             ['Authors', FILTER_AUTHORS],
             ['ISBNs', FILTER_ISBNS],
             ['Publishers', FILTER_PUBLISHERS],
             ['Notes', FILTER_NOTES]].each do |category, type|
                menuItem = NSMenuItem.alloc.initWithTitle(category, :action, :_updateSearchCategory_,
                                                                    :keyEquivalent, "")
                menuItem.setTarget(self)
                menuItem.setRepresentedObject(type)
                menuItem.setState(NSOffState)
                
                menu.addItem(menuItem)
            end
            menu.itemAtIndex(0).setState(NSOnState)
            @searchCategory = FILTER_ALL
            @toolbarSearchField.cell.setSearchMenuTemplate(menu)
        end
    
        def _setupLibrariesTableView
            librariesColumn = @librariesTableView.tableColumnWithIdentifier(:libraries)
            librariesColumn.setResizingMask(1) # NSTableColumnAutoresizingMask
            librariesColumn.setDataCell(TitledImageCell.alloc.init)
            @librariesTableView.setDoubleAction(:doubleClickOnLibraries_)
            @librariesTableView.setTarget(self)
        end

        def _setupViews
            titleColumn = @booksTableView.tableColumnWithIdentifier(:title)
            titleColumn.setDataCell(TitledImageCell.alloc.init)
            ratingColumn = @booksTableView.tableColumnWithIdentifier(:rating)
            ratingColumn.setDataCell(RatingCell.alloc.init)
            @booksTableView.setDoubleAction(:doubleClickOnBooks_)
            @booksTableView.setTarget(self)
        end

        def _setBooksView(type)
            @booksView.subviews.to_a.each { |x| x.removeFromSuperviewWithoutNeedingDisplay }
            case type
                when VIEW_AS_ICON
                    # TODO

                when VIEW_AS_LIST
                    realView = @booksTableView.superview.superview
                    realView.setFrameSize(@booksView.frame.size)
                    @booksView.addSubview(realView)
            end
            @booksView.setNeedsDisplay(TRUE)
        end
        
        def _focusOnBooksView?
            responder = @mainWindow.firstResponder
            responder != nil and responder.__ocid__ == @booksTableView.__ocid__
        end
        
        def _focusOnLibraryView?
            responder = @mainWindow.firstResponder
            responder != nil and responder.__ocid__ == @librariesTableView.__ocid__
        end
    end
end
end