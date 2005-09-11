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
                   :addBookController, :toolbarSearchField,
                   :bookInfoController, :aboutController, :booksMatrix,
                   :booksIconView, :booksListView, :splitView,
                   :exportController, :importController, :preferencesController,
                   :onlineInfoMenuItem
        
        attr_reader :booksTableView
        
        VIEW_AS_ICON, VIEW_AS_LIST = 0, 1
        
        def awakeFromNib
            _setupSearchField
            _setupLibrariesTableView
            _setupViews
            _setupToolbar
            _setupMenus
        end
        
        # NSWindow delegation
        
        def windowDidBecomeKey(notification)
            # FIXME: MainController should inherit of NSWindowController and we should
            # do the following in windowDidLoad.
            @windowLoaded ||= false
            unless @windowLoaded
                @windowLoaded = true
                _restorePreferences
            end
        end

        # NSToolbar delegation

        TOOLITEM_NEW, TOOLITEM_ADD, TOOLITEM_SEARCH, TOOLITEM_VIEW_AS_ICONS,
            TOOLITEM_VIEW_AS_LIST = (0..4).to_a.map { |x| x.to_s }
        
        def _setupToolbar
            toolbar = NSToolbar.alloc.initWithIdentifier('myToolbar')
            toolbar.setDisplayMode(NSToolbarDisplayModeIconAndLabel)
            toolbar.setDelegate(self)
            toolbar.setAutosavesConfiguration(true)
            toolbar.setAllowsUserCustomization(false)
            @mainWindow.setToolbar(toolbar)
            @toolbarItems = {}
            @mainWindow.toolbar.items.to_a.each do |toolItem|
                @toolbarItems[toolItem.itemIdentifier.to_s] = toolItem
            end
        end
    
        def _filterCriterion
            @toolbarSearchField.stringValue.UTF8String.strip.downcase
        end

        def _filterBooks(sender)
            criterion = _filterCriterion
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
                            [ book.title, book.authors.join(', '), book.isbn,
                              book.publisher, (book.notes or "") ].join(' ')
                    end
                    s.downcase.include?(criterion)
                end
                label = _("%d of %d") % [ filteredLibrary.length, _selectedLibrary.length ]
            else
                filteredLibrary = _selectedLibrary
                label = _("Search")
            end
            
            @toolbarItems[TOOLITEM_SEARCH].setLabel(label)
            
            @booksTableView.dataSource.library = filteredLibrary
            @booksTableView.reloadData

            _updateWindowTitle
            _relayoutBooksMatrix
         end
        
        def toolbar_itemForItemIdentifier_willBeInsertedIntoToolbar(toolbar, identifier, flag)
            toolitem = NSToolbarItem.alloc.initWithItemIdentifier(identifier)
            case identifier.to_s
                when TOOLITEM_NEW
                    toolitem.setLabel(_('New Library'))
                    toolitem.setImage(Icons::LIBRARY)
                    toolitem.setAction(:newLibrary)
                    toolitem.setTarget(self)
                when TOOLITEM_ADD
                    toolitem.setLabel(_('Add Book'))
                    toolitem.setImage(Icons::BOOK)
                    toolitem.setAction(:addBook)
                    toolitem.setTarget(self)
                when TOOLITEM_SEARCH
                    toolitem.setLabel(_('Search'))
                    toolitem.setView(@toolbarSearchView)
                    height = @toolbarSearchView.frame.size.height
                    toolitem.setMinSize(NSSize.new(150, height))
                when TOOLITEM_VIEW_AS_ICONS
                    toolitem.setLabel(_('View As Icons'))
                    toolitem.setImage(Icons::VIEW_AS_ICONS)
                    toolitem.setAction(:viewAsIcons)
                    toolitem.setTarget(self)
                    toolitem.setAutovalidates(false)
                when TOOLITEM_VIEW_AS_LIST
                    toolitem.setLabel(_('View As List'))
                    toolitem.setImage(Icons::VIEW_AS_LIST)
                    toolitem.setAction(:viewAsList)
                    toolitem.setTarget(self)
                    toolitem.setAutovalidates(false)
            end
            return toolitem.retain
        end
        
        def toolbarDefaultItemIdentifiers(toolbar)
            [TOOLITEM_NEW, 
             TOOLITEM_ADD, 
             OSX.NSToolbarFlexibleSpaceItemIdentifier,
             TOOLITEM_SEARCH,
             OSX.NSToolbarFlexibleSpaceItemIdentifier,
             TOOLITEM_VIEW_AS_ICONS,
             TOOLITEM_VIEW_AS_LIST]
        end
        
        def toolbarAllowedItemIdentifiers(toolbar)
            toolbarDefaultItemIdentifiers(toolbar)
        end
        
        # NSViewFrameDidChangeNotification
        
        def booksViewFrameDidChange(notification)
            _relayoutBooksMatrix(false)
        end
        
        # NSSplitView delegation

        def splitView_canCollapseSubview(splitView, view)
            false
        end

        def splitView_constrainMinCoordinate_ofSubviewAt(splitView, proposedMin, offset)
            @splitViewToggled = false
            @positionAdjust = nil
            if _sidepaneHidden?
                proposedMin
            else
                offset == 0 ? 100 : proposedMin
            end
        end

        def splitView_constrainMaxCoordinate_ofSubviewAt(splitView, proposedMax, offset)
            if _sidepaneHidden?
                proposedMax
            else
                offset == 0 ? 400 : proposedMax
            end
        end
        
        def splitView_constrainSplitPosition_ofSubviewAt(splitView, proposedPosition, offset)
            event = @mainWindow.currentEvent
            if event.oc_type == NSLeftMouseDragged
                mouseX = event.locationInWindow.x
                if mouseX < 100 
                    if _sidepaneHidden?
                        proposedPosition = 0
                    elsif mouseX < 20 and !@splitViewToggled
                        toggleSidepane(self)
                        @splitViewToggled = true
                    end
                else
                    if !@splitViewToggled and _sidepaneHidden?
                        toggleSidepane(self)
                        @splitViewToggled = true
                        proposedPosition = 100
                        @positionAdjust = 100 - mouseX
                    end
                end
            end
            if @positionAdjust
                proposedPosition += @positionAdjust
                proposedPosition = 100 if proposedPosition < 100
            end
            return proposedPosition
        end
        
        def splitView_resizeSubviewsWithOldSize(splitView, oldSize)
            # Do not change the sidepane's width
            sidepaneWidth = _sidepaneView.frame.size.width
            _sidepaneView.setFrameSize(NSSize.new(sidepaneWidth, oldSize.height))
            
            # Resize the books view
            width = oldSize.width - sidepaneWidth - splitView.dividerThickness
            @booksView.setFrameSize(NSSize.new(width, oldSize.height))
        end

        # NSMatrix delegation
        
        def matrix_deleteCharacterDown(matrix, event)
            _deleteSelectedBooks
        end
        
        def matrix_popupMenuForEvent(matrix, event)
            _popupMenuForBooks
        end
        
        # NSTableView delegation
        
        def tableViewSelectionDidChange(notification)
            tableView = notification.object
            if tableView.__ocid__ == @librariesTableView.__ocid__
                @booksMatrix.deselectAllCells
                @booksTableView.deselectAll(self)
                _filterBooks(nil)
                _updateWindowTitle
                if @windowLoaded 
                    # Avoid race condition
                    Preferences.instance.selected_library = _selectedLibrary.name 
                end
            end
        end

        def tableView_shouldEditTableColumn_row(tableView, tableColumn, row)
            if tableView.__ocid__ == @librariesTableView.__ocid__
                true
            elsif tableView.__ocid__ == @booksTableView.__ocid__
                tableColumn.identifier.to_s != 'rating'
            end
        end

        def tableView_deleteCharacterDown(tableView, event)
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
                _updateWindowTitle
            end
        end

        def acceptedDropOnTableView(tableView)
            if tableView.__ocid__ == @librariesTableView.__ocid__
                _filterBooks(nil)
                @booksMatrix.deselectAllCells
            end
        end
        
        def tableView_popupMenuForEvent(tableView, event)
            if tableView.__ocid__ == @booksTableView.__ocid__
                _popupMenuForBooks
            elsif tableView.__ocid__ == @librariesTableView.__ocid__
                menu = NSMenu.alloc.init
                
                point = tableView.convertPoint_fromView(event.locationInWindow, nil)
                row = tableView.rowAtPoint(point)
                
                if row != -1
                    menuItem = NSMenuItem.alloc.init
                    menuItem.setTitle(_('Export'))
                    menuItem.setTarget(self)
                    menuItem.setAction('export:')
                    menu.addItem(menuItem)
                    
                    menuItem = NSMenuItem.alloc.init
                    menuItem.setTitle(_('Delete'))
                    menuItem.setTarget(self)
                    menuItem.setAction('delete:')
                    menu.addItem(menuItem)
                else
                    menuItem = NSMenuItem.alloc.init
                    menuItem.setTitle(_('New Library'))
                    menuItem.setTarget(self)
                    menuItem.setAction('newLibrary:')
                    menu.addItem(menuItem)
                end

                return menu
            end
        end

        # NSTextField delegation
        
        def controlTextDidChange(notification)
            view = notification.object
            if view.__ocid__ == @toolbarSearchField.__ocid__
                NSObject.cancelPreviousPerformRequestsWithTarget(self, :selector, :_filterBooks_,
                                                                       :object, nil)
                if @toolbarSearchField.stringValue.to_s.strip.empty?
                    _filterBooks(nil)
                else
                    self.performSelector(:_filterBooks_, :withObject, nil,
                                                         :afterDelay, 0.5)
                end
            end
        end

        # Completion

        def textView_completions_forPartialWordRange_indexOfSelectedItem(textView, words, charRange, index)
            # TODO
            p 'completion'
            return NSArray.array
        end

        # NSMenuItem validation

        def validateMenuItem(menuItem)
            return false unless @mainWindow.isKeyWindow?

            case menuItem.action.to_s
                when 'getInfo:'
                    _focusOnBooksView? and _selectedBooks.length == 1

                when 'viewOnlineInformation:'
                    books = _selectedBooks
                    if _focusOnBooksView? and books.length == 1
                        name = menuItem.representedObject.to_s
                        unless name.empty?
                            bookProvider = BookProviders.find { |x| x.name == name }
                            bookProvider.url(books.first) != nil
                        else
                            true
                        end
                    end

                when 'arrangeIcons:'
                    menuItem.setState(@arrangeIconsMode == menuItem.tag ? NSOnState : NSOffState)
                    @booksViewType == VIEW_AS_ICON

                when 'toggleIconsOrder:'
                    menuItem.setState(@reverseIcons ? NSOnState : NSOffState)
                    @booksViewType == VIEW_AS_ICON

                when 'export:'
                    !_selectedLibrary.empty?

                when 'about:'
                    !@aboutController.opened?

                when 'delete:'
                    (_focusOnBooksView? and !_selectedBooks.empty?) or _focusOnLibraryView?

                when 'clearSearchResults:'
                    !@toolbarSearchField.stringValue.to_s.empty?

                when 'viewAsIcons:'
                    menuItem.setState(@booksViewType == VIEW_AS_ICON ? NSOnState : NSOffState)
                    true

                when 'viewAsList:'
                    menuItem.setState(@booksViewType == VIEW_AS_LIST ? NSOnState : NSOffState)
                    true
                
                when 'toggleToolbar:'
                    menuItem.setTitle((@mainWindow.toolbar.isVisible?) ? _('Hide Toolbar') : _('Show Toolbar'))
                    true

                when 'toggleSidepane:'
                    menuItem.setTitle((_sidepaneHidden?) ? _('Show Libraries') : _('Hide Libraries'))
                    true
                    
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
            @bookInfoController.openWindowToEdit(dataSource.library, 
                                                 books.first) do |modifiedBooks|
                unless modifiedBooks.empty?
                    modifiedBooks.each do |book|
                        dataSource.flushCachedInfoForBook(book)
                    end
                    unless _filterCriterion.empty?
                        # The views are filtered, we have to refilter the source again.
                        _filterBooks(nil)
                    else
                        # Just reload the views.
                        @booksTableView.reloadData
                        @booksMatrix.reloadData
                        _updateWindowTitle
                    end
                end
            end
        end
    
        def newLibrary(sender)
            toggleSidepane(self) if _sidepaneHidden?
            library = @librariesTableView.dataSource.addLibraryWithAutogeneratedName
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

        def addBookManually(sender)
            dataSource = @booksTableView.dataSource
            @bookInfoController.openWindowToAdd(dataSource.library) do |newBook|
                @booksTableView.reloadData
                @booksMatrix.reloadData
                _updateWindowTitle
            end
        end

        def delete(sender)
            if _focusOnBooksView?
                _deleteSelectedBooks
            elsif _focusOnLibraryView?
                _deleteSelectedLibrary
            end 
        end
        
        def find(sender)
            toolbar = @mainWindow.toolbar
            unless toolbar.isVisible?
                toolbar.setVisible(true)
            end
            @mainWindow.makeFirstResponder(@toolbarSearchField)
        end
        
        def clearSearchResults(sender)
            @toolbarSearchField.setStringValue("")
            _filterBooks(nil)
        end
        
        def doubleClickOnLibraries(sender)
            # Do nothing.
        end
        
        def doubleClickOnBooks(sender)
            getInfo(sender)
        end
        
        def viewAsIcons(sender)
            _setBooksView(VIEW_AS_ICON)
        end

        def viewAsList(sender)
            _setBooksView(VIEW_AS_LIST)
        end
        
        def toggleSidepane(sender)
            frame = _sidepaneView.frame
            if _sidepaneHidden?
                # Show sidepane
                Preferences.instance.sidepane_visible = true
                @previousSidepaneWidth ||= 100
                frame.size.width = @previousSidepaneWidth
                frame.size.height = @booksView.frame.size.height
                _sidepaneView.setFrame(frame)
                
                # Accordingly reduce the books view
                frame = @booksView.frame
                frame.origin.x += @previousSidepaneWidth
                frame.size.width -= @previousSidepaneWidth
                @booksView.setFrame(frame)
            else
                # Hide sidepane, no need to adjust the books view
                Preferences.instance.sidepane_visible = false
                @previousSidepaneWidth = frame.size.width
                frame.size.width = 0
                _sidepaneView.setFrame(frame)
            end
            @splitView.adjustSubviews        
        end
        
        def toggleToolbar(sender)
            @mainWindow.toggleToolbarShown(sender)
        end
        
        def import(sender)
            @importController.openWindow do |newLibrary|
                @librariesTableView.dataSource.libraries << newLibrary
                @librariesTableView.reloadData
                _selectLibrary(newLibrary)
            end
        end
        
        def export(sender)
            @exportController.openWindow(_selectedLibrary)
        end

        def preferences(sender)
            @preferencesController.openWindow
        end

        def viewOnlineInformation(sender)
            providerName = sender.representedObject.to_s
            provider = BookProviders.instance.find { |x| x.name == providerName }
            if provider
                urlString = provider.url(_selectedBooks.first)
                if urlString
                    url = NSURL.URLWithString(urlString)
                    NSWorkspace.sharedWorkspace.openURL(url)
                end
            end
        end

        def arrangeIcons(sender)            
            @arrangeIconsMode = sender.tag
            _sortBooksMatrix
        end
        
        def toggleIconsOrder(sender)
            @reverseIcons = !@reverseIcons
            _sortBooksMatrix
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
            if _viewAsIcons?
                dataSource = @booksMatrix.dataSource
                @booksMatrix.selectedCells.to_a.each do |cell|
                    next if cell.objectValue.nil?
                    row = @booksMatrix.rowOfCell(cell)
                    next if row == -1
                    col = @booksMatrix.columnOfCell(cell)
                    next if col == -1
                    books << dataSource.matrix_bookForColumn_row(@booksMatrix, 
                                                                 col, 
                                                                 row)
                end
            else
                selection = @booksTableView.selectedRowIndexes
                dataSource = @booksTableView.dataSource
                if selection.count > 0
                    index = selection.firstIndex
                    begin
                        books << dataSource.tableView_bookAtRow(@booksTableView, index)
                        index = selection.indexGreaterThanIndex(index)
                    end while index != NSNotFound
                end
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
                  "from '%s'?") % [ books_to_delete.first.title.to_utf8_nsstring, 
                                    library.name ]
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
            pboardTypes = [BooksDataSource::PASTEBOARD_TYPE]
            @librariesTableView.registerForDraggedTypes(pboardTypes)
        end

        def _relayoutBooksMatrix(dataChanged=true)            
            # Compute the new size of the matrix
            library = @booksMatrix.dataSource.library
            nBooks = library.length
            matrixFrame = @booksMatrix.frame
            intercellWidth, intercellHeight = @booksMatrix.intercellSpacing.to_a
            width = matrixFrame.size.width
            nCols = ((width + intercellWidth) / (BooksDataSource::ICON_WIDTH.to_f + intercellWidth)).floor
            nCols = 1 if nCols == 0
            nRows = (nBooks / nCols.to_f).ceil

            # Current and new sizes are the same
            if @booksMatrix.numberOfRows == nRows and 
               @booksMatrix.numberOfColumns == nCols
                
                # Do nothing if the data did not change
                return unless dataChanged
            else                         
                # Resize
                newHeight = [ (nRows * BooksDataSource::ICON_HEIGHT) + intercellHeight * (nRows - 1), 
                              @booksMatrix.superview.frame.height ].max
                matrixFrame.size.height = newHeight
                @booksMatrix.setFrame(matrixFrame)
                @booksMatrix.renewRows_columns(nRows, nCols)
            end

            @booksMatrix.reloadData
        end

        def _setupViews            
            # icons
            @booksMatrix.setDataSource(@booksTableView.dataSource)
            @booksMatrix.setDelegate(self)
            @booksMatrix.setCellClass(BookIconCell.oc_class)
            cellSize = NSSize.new(BooksDataSource::ICON_WIDTH, 
                                  BooksDataSource::ICON_HEIGHT)
            @booksMatrix.setCellSize(cellSize)
            @booksMatrix.setIntercellSpacing(NSSize.new(18, 8))
            @booksMatrix.setAllowsEmptySelection(true)
            @booksMatrix.setSelectionByRect(true)
            @booksMatrix.setAutoscroll(true)
            @booksMatrix.setTabKeyTraversesCells(true)
            @booksMatrix.setMode(NSListModeMatrix)
            @booksMatrix.setFocusRingType(NSFocusRingTypeNone)
            @booksMatrix.setTarget(self)
            @booksMatrix.setDoubleAction(:doubleClickOnBooks_)
            @arrangeIconsMode = 0
            @reverseIcons = false
            
            # list
            titleColumn = @booksTableView.tableColumnWithIdentifier(:title)
            titleColumn.setDataCell(TitledImageCell.alloc.init)
            ratingColumn = @booksTableView.tableColumnWithIdentifier(:rating)
            ratingColumn.setDataCell(RatingCell.alloc.init)
            @booksTableView.setDoubleAction(:doubleClickOnBooks_)
            @booksTableView.setTarget(self)
            
            NSNotificationCenter.defaultCenter.addObserver(self, :selector, "booksViewFrameDidChange:",
                                                                 :name, 'NSViewFrameDidChangeNotification',
                                                                 :object, @booksView)
        end

        def _setBooksView(type)
            return if @booksViewType == type
            wasFirstResponder = _focusOnBooksView?
            @booksViewType = type
            Preferences.instance.view_as = type

            # Remove previous books view
            @booksView.subviews.to_a.each { |x| x.removeFromSuperviewWithoutNeedingDisplay }
            
            # Setup new books view
            newView, newControl = type == VIEW_AS_ICON ? [@booksIconView, @booksMatrix] : [@booksListView, @booksTableView]
            newView.setFrame(@booksView.bounds)
            @booksView.addSubview(newView)
            @mainWindow.makeFirstResponder(newControl) if wasFirstResponder
            @librariesTableView.setNextKeyView(newControl)
            newControl.setNextKeyView(@librariesTableView)

            # Sensitize the 'view as' toolbar items
            @toolbarItems[TOOLITEM_VIEW_AS_ICONS].setEnabled(type != VIEW_AS_ICON)
            @toolbarItems[TOOLITEM_VIEW_AS_LIST].setEnabled(type == VIEW_AS_ICON)

            # Redraw
            @booksView.setNeedsDisplay(true)
            _relayoutBooksMatrix if type == VIEW_AS_ICON
        end
        
        def _viewAsIcons?
            @booksViewType == VIEW_AS_ICON
        end

        def _viewAsList?
            @booksViewType == VIEW_AS_LIST
        end

        def _focusOnBooksView?
            responder = @mainWindow.firstResponder
            responder != nil and (responder.__ocid__ == @booksTableView.__ocid__ or
                                  responder.__ocid__ == @booksMatrix.__ocid__)
        end
        
        def _focusOnLibraryView?
            responder = @mainWindow.firstResponder
            responder != nil and responder.__ocid__ == @librariesTableView.__ocid__
        end
        
        def _sidepaneView
            @librariesTableView.superview.superview
        end
        
        def _sidepaneHidden?
            _sidepaneView.frame.size.width == 0
        end
        
        def _updateWindowTitle
            library = _selectedLibrary
            title = if library.empty?
                library.name
            else
                s = library.name
                s += ' ('
                n_unrated = library.n_unrated
                if n_unrated == library.length
                    s += n_("%d unrated book", "%d unrated books", library.length) % library.length
                else
                    s += n_("%d book", "%d books", library.length) % library.length
                    if n_unrated > 0
                        s += ", "
                        s += n_("%d unrated", "%d unrated", n_unrated) % n_unrated
                    end
                end
                s += ")"
                s
            end
            @mainWindow.setTitle(title)
        end

        def _restorePreferences
            preferences = Preferences.instance

            # Selected library
            libraries = @librariesTableView.dataSource.libraries
            library = nil
            if name = preferences.selected_library
                library = libraries.find { |x| x.name == name }
            end
            library ||= libraries.first
            _selectLibrary(library)
            
            # View as mode
            mode = preferences.view_as
            _setBooksView(mode != nil ? mode : VIEW_AS_ICON)
            
            # Table columns visibility
            @booksTableView.tableColumns.to_a.each do |tableColumn|
                id = tableColumn.identifier.to_s
                message = "col_#{id}_visible"
                if visible = preferences.send(message)
                    if visible == 0
                        @booksTableView.setHidden_forColumnWithIdentifier(true, id)
                    end
                end
            end
            
            # Sidepane
            if visible = preferences.sidepane_visible
                if visible == 0
                    toggleSidepane(self)
                end
            end

            @arrangeIconsMode = 0
            @reverseIcons = false
            _sortBooksMatrix
        end
        
        def _setupMenus
            _buildOnlineInformationMenu(@onlineInfoMenuItem.submenu)
        end
        
        def _sortBooksMatrix
            key = case @arrangeIconsMode
                when 0
                    :title
                when 1
                    :authors
                when 2
                    :isbn
                when 3
                    :publisher
                when 4
                    :edition
                when 5
                    :rating
            end
            ascending = @reverseIcons
            sortDescriptor = NSSortDescriptor.alloc.initWithKey_ascending(key, ascending)
            @booksMatrix.sortUsingSortDescriptor(sortDescriptor)
        end

        def _buildOnlineInformationMenu(menu)
            menu.numberOfItems.times { |i| p i; menu.removeItemAtIndex(i) }
            BookProviders.instance.sort.each do |bookProvider|
                menuItem = NSMenuItem.alloc.init
                menuItem.setTitle(bookProvider.fullname)
                menuItem.setTarget(self)
                menuItem.setAction('viewOnlineInformation_')
                menuItem.setRepresentedObject(bookProvider.name)
                menu.addItem(menuItem)
            end
        end

        def _popupMenuForBooks
            menu = NSMenu.alloc.init
            
            newItem = proc do |title, selector|
                menuItem = NSMenuItem.alloc.init
                menuItem.setTitle(title)
                menuItem.setTarget(self)
                menuItem.setAction(selector)
                menuItem
            end
            
            newItemWithMenu = proc do |title, selector, submenu|
                menuItem = newItem.call(title, selector)
                menuItem.setSubmenu(submenu)
                menuItem
            end
            
            books = _selectedBooks
            if books.empty?
                menu.addItem(newItem.call(_('Add Book'), 'addBook:'))
                menu.addItem(newItem.call(_('Add Book Manually'), 'addBookManually:'))
            else
                menu.addItem(newItem.call(_('Get Info'), 'getInfo:'))
                menu.addItem(newItem.call(_('Delete'), 'delete:'))

                submenu = NSMenu.alloc.init
                _buildOnlineInformationMenu(submenu)
                menu.addItem(newItemWithMenu.call(_('View Online Information At'), 'viewOnlineInformation:', submenu))                
            end

            menu.addItem(NSMenuItem.separatorItem)

            menu.addItem(newItem.call(_('View As Icons'), 'viewAsIcons:'))
            menu.addItem(newItem.call(_('View As List'), 'viewAsList:'))

            menu.addItem(NSMenuItem.separatorItem)

            submenu = NSMenu.alloc.init
            [ _('Title'), _('Authors'), _('ISBN'), 
              _('Publisher'), _('Binding'), _('Rating') ].each_with_index do |title, i|
                menuItem = newItem.call(title, 'arrangeIcons:')
                menuItem.setTag(i)
                submenu.addItem(menuItem)
            end
            submenu.addItem(NSMenuItem.separatorItem)
            submenu.addItem(newItem.call(_('Reverse Order'), 'toggleIconsOrder:'))
            menuItem = newItemWithMenu.call(_('Arrange Icons By'), 'arrangeIcons:', submenu)
            menuItem.setTag(69)
            menu.addItem(menuItem)

            return menu
        end
    end
end
end