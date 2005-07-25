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
    class FakeVariable
        attr_reader :name, :description, :possible_values, :value
    
        def initialize(name, description, default_value, possible_values=nil, mandatory=true)
            @name = name
            @description = description
            @value = default_value
            @possible_values = possible_values
            @mandatory = mandatory
        end
        
        def mandatory?
            @mandatory
        end
    end

    class ProviderPreferencesController < OSX::NSObject
        include OSX

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
        
        ib_outlets :window, :preferencesWindow, :contentView, :buttonsView
        
        SETUP_MODE, ADD_MODE = 1, 2
        
        def openWindowToSetup(provider, &close_cb)
            @mode, @provider, @close_cb = SETUP_MODE, provider, close_cb
            _setupContentView(@provider.prefs.read)
            _openWindow
        end
        
        def openWindowToAdd(&close_cb)
            @mode, @close_cb = ADD_MODE, close_cb
            # FIXME: this should be rewritten once there will be more than one
            # abstract provider!
            @instance = BookProviders.abstract_classes.first.new
            variables = []
            variables << FakeVariable.new('name', _('Name'), _('Untitled source'))
            variables << FakeVariable.new('type', _('Type'), @instance.fullname, [@instance.fullname])
            variables.concat(@instance.prefs)
            _setupContentView(variables)
            @addButton.setEnabled(false)
            _openWindow
        end

        # Actions

        def add(sender)
            NSApplication.sharedApplication.endSheet_returnCode(@window, 1)
        end

        def close(sender)
            NSApplication.sharedApplication.endSheet_returnCode(@window, 0)
        end

        # Sheet delegation

        def sheetDidEnd_returnCode_contextInfo(sheetWindow, returnCode, contextInfo)
            sheetWindow.orderOut(self)            
            if @mode == SETUP_MODE
                _syncVariables
                @close_cb.call
            else
                if returnCode == 1
                    name = nil
                    @variableControls.each do |variable, control|
                        if variable.is_a?(FakeVariable) and variable.name == 'name'
                            name = control.stringValue.to_s
                        end
                    end
                    if name
                        @instance.reinitialize(name)
                        _syncVariables
                        @close_cb.call(@instance)
                    end
                end
            end
        end

        # NSTextField delegation

        def controlTextDidChange(notification)
            if @mode == ADD_MODE
                ok = true
                @variableControls.each do |variable, control|
                    next unless variable.mandatory?
                    if control.stringValue.to_s.strip.empty?
                        ok = false
                        break
                    end
                end
                @addButton.setEnabled(ok)
            end
        end

        #######
        private
        #######

        def _setupContentView(variables)
            controls = []
    
            biggestLabelWidth = biggestValueWidth = totalHeight = 0
            
            @window.setMinSize(NSSize.new(1000, 1000))
            @variableControls = {}
            
            variables.reverse.each do |variable|
                label = NSTextField.alloc.initWithFrame(NSRect.new(0, 0, 0, 0))
                label.setStringValue(variable.description + ':')
                label.setEditable(false)
                label.setBordered(false)
                label.setDrawsBackground(false)
                label.sizeToFit
                width = label.frame.size.width
                if width > biggestLabelWidth
                    biggestLabelWidth = width
                end

                unless variable.possible_values.nil?
                    valueControl = NSPopUpButton.alloc.initWithFrame_pullsDown(NSRect.new(0, 0, 0, 0), 
                                                                               false)
                    variable.possible_values.each do |value|
                        valueControl.addItemWithTitle(value.to_s)
                    end
                    index = variable.possible_values.index(variable.value)
                    valueControl.selectItemAtIndex(index)
#                    valueControl.cell.setControlSize(NSSmallControlSize)
#                    valueControl.setFont(NSFont.systemFontOfSize(NSFont.smallSystemFontSize))
                else
                    valueControl = NSTextField.alloc.initWithFrame(NSRect.new(0, 0, 0, 0))
                    valueControl.setStringValue(variable.value.to_s)
                    valueControl.setDelegate(self)
                end
                valueControl.sizeToFit
                valueControlSize = valueControl.frame.size
                width = valueControlSize.width
                if width > biggestValueWidth
                    biggestValueWidth = width
                end
                totalHeight += valueControlSize.height + 8
                @variableControls[variable] = valueControl
                controls << [label, valueControl]
            end

            @contentView.subviews.to_a.each { |x| x.removeFromSuperviewWithoutNeedingDisplay }

            if biggestValueWidth < biggestLabelWidth
                biggestValueWidth = biggestLabelWidth
            elsif biggestValueWidth < 150
                biggestValueWidth = 150
            end

            frame = @contentView.frame
            frame.size.width = biggestLabelWidth + 10 + biggestValueWidth
            frame.size.height = totalHeight
            @contentView.setFrameSize(frame.size)
    
            valueYOrigin = 0

            controls.each_with_index do |ary, i|
                label, value = ary
                @contentView.addSubview(value)
                frame = value.frame
                frame.origin = NSPoint.new(biggestLabelWidth + 10, valueYOrigin)
                frame.size.width = biggestValueWidth
#                frame.size.height = 22
                value.setFrame(frame)                

                @contentView.addSubview(label)
                frame = label.frame
                origin = NSPoint.new(biggestLabelWidth - frame.size.width, 
                                     value.frame.origin.y + ((value.frame.size.height - label.frame.size.height) / 2.0).ceil)
#                if value.isKindOfClass(NSPopUpButton.oc_class)
#                    origin.y += 1
#                end
                label.setFrameOrigin(origin)
                
                valueYOrigin += value.frame.size.height + 8
            end

            buttons = case @mode
                when ADD_MODE
                    [[_('Cancel'), :close], [_('Add'), :add]]
                when SETUP_MODE
                    [[_('Close'), :close]]
            end

            buttonOrigin = NSPoint.new(@contentView.frame.size.width + 5, 2)

            @buttonsView.subviews.to_a.each { |x| x.removeFromSuperviewWithoutNeedingDisplay }

            buttons.reverse.each do |title, selector|
                button = NSButton.alloc.initWithFrame(NSRect.new(0, 0, 0, 0))
                button.setBezelStyle(NSRoundedBezelStyle)
                button.setTitle(title)
                button.setTarget(self)
                button.setAction(selector)
                button.sizeToFit

                @buttonsView.addSubview(button)

                frame = button.frame
                if frame.size.width < 80
                    frame.size.width = 80
                end
                buttonOrigin.x -= frame.size.width
                frame.origin = buttonOrigin
                button.setFrame(frame)
                buttonOrigin.x -= 4
                
                instance_variable_set("@#{selector}Button".intern, button)
            end 

            frame = @window.frame
            frame.size.width = biggestLabelWidth + 50 + biggestValueWidth
            oldHeight = frame.size.height
            frame.size.height = @contentView.frame.size.height + 80
            @window.setContentSize(frame.size)
            frame.origin.y -= oldHeight - frame.size.height
            @window.setFrame_display(frame, false)

            @contentView.setFrameOrigin(NSPoint.new(20, 60))
        end

        def _openWindow
            size = @window.frame.size
           
            app = NSApplication.sharedApplication
            app.beginSheet(@window, :modalForWindow, @preferencesWindow,
                                    :modalDelegate, self,
                                    :didEndSelector, :sheetDidEnd_returnCode_contextInfo_,
                                    :contextInfo, nil)

            frame = @window.frame
            delta = frame.size.height - size.height
            frame.size.height -= delta
            frame.origin.y += delta
            @window.setFrame_display(frame, true)
        end
        
        def _syncVariables
            @variableControls.each do |variable, control|
                next if variable.is_a?(FakeVariable)
                variable.new_value = case control
                    when NSTextField
                        control.stringValue.to_s

                    when NSPopUpButton
                        idx = control.indexOfSelectedItem
                        variable.possible_values[idx]

                    else
                        raise
                end
            end
        end
    end

    class PreferencesController < OSX::NSObject
        include OSX

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        ib_outlets :panel, :authorsButton, :isbnButton, :publisherButton,
                   :bindingButton, :ratingButton, :mainController,
                   :addProviderButton, :removeProviderButton,
                   :providersTableView, :providersPreferencesController,
                   :setupProviderButton, :tabView

        PROVIDERS_PASTEBOARD_TYPE = :ProvidersPBoardType

        def awakeFromNib
            @addProviderButton.setImage(Icons::MORE)
            @removeProviderButton.setImage(Icons::LESS)
            
            @providersTableView.setTarget(self)
            @providersTableView.setDoubleAction(:doubleClickOnProvidersTableView_)

            pboardTypes = [PROVIDERS_PASTEBOARD_TYPE]
            @providersTableView.registerForDraggedTypes(pboardTypes)
        end
        
        def openWindow
            tableView = @mainController.booksTableView

            [@authorsButton, @isbnButton, @publisherButton, 
             @bindingButton, @ratingButton].each do |button|
                id = _identifierForButton(button)
                state = tableView.isColumnWithIdentifierHidden(id) ? NSOffState : NSOnState
                button.setState(state)
            end
        
            @providersTableView.deselectAll(self)
            @removeProviderButton.setEnabled(false)
            @setupProviderButton.setEnabled(false)

            _updateTitle

            @panel.makeKeyAndOrderFront(self)
        end
        
        # Actions
        
        def toggleShowColumn(sender)
            hide = sender.state == NSOffState
            tableView = @mainController.booksTableView
            id = _identifierForButton(sender)
            tableView.setHidden_forColumnWithIdentifier(hide, id)
            message = "col_#{id}_visible="
            Preferences.instance.send(message, !hide)
        end
        
        def addProvider(sender)
            @panel.setTitle(_('New Provider'))
            @providersPreferencesController.openWindowToAdd do |new_provider|
                BookProviders.update_priority
                @providersTableView.reloadData
            end
        end
        
        def removeProvider(sender)
            _selectedProvider.remove
            BookProviders.update_priority
            @providersTableView.reloadData
        end
        
        def doubleClickOnProvidersTableView(sender)
            setupProvider(sender)
        end
        
        def setupProvider(sender)
            provider = _selectedProvider
            if provider != nil and !provider.prefs.empty?
                @panel.setTitle(_('%s Preferences') % provider.fullname)
                @providersPreferencesController.openWindowToSetup(provider) do
                    _updateTitle
                end
            end
        end
        
        # NSWindow delegation

        def windowWillClose(notification)
        end
        
        # NSTableView datasource
        
        def numberOfRowsInTableView(tableView)
            BookProviders.instance.length 
        end
        
        def tableView_objectValueForTableColumn_row(tableView, col, row)
            BookProviders.instance[row].fullname
        end

        def tableView_writeRowsWithIndexes_toPasteboard(tableView, rowIndexes, pasteboard)
            return if rowIndexes.count != 1
            pos = rowIndexes.firstIndex
            provider = BookProviders.instance[pos]
            pasteboard.declareTypes_owner(NSArray.arrayWithObject(PROVIDERS_PASTEBOARD_TYPE),
                                          self)
            pasteboard.setString_forType(provider.name, PROVIDERS_PASTEBOARD_TYPE)
            return true
        end

        def tableView_validateDrop_proposedRow_proposedDropOperation(tableView, draggingInfo, row, operation)            
            unless operation == NSTableViewDropAbove
                return NSDragOperationNone  
            end

            pasteboard = draggingInfo.draggingPasteboard
            unless pasteboard.types.containsObject?(PROVIDERS_PASTEBOARD_TYPE)
                return NSDragOperationNone
            end

            return NSDragOperationMove
        end

        def tableView_acceptDrop_row_dropOperation(tableView, draggingInfo, row, operation)
            pasteboard = draggingInfo.draggingPasteboard
            unless pasteboard.types.containsObject?(PROVIDERS_PASTEBOARD_TYPE)
                return false
            end
            
            providerName = pasteboard.stringForType(PROVIDERS_PASTEBOARD_TYPE).to_s
            provider = BookProviders.instance.find { |x| x.name == providerName }
            return if provider.nil?
            
            priority = BookProviders.instance.map { |x| x.name }
            idx = priority.index(providerName)
            priority[idx] = nil
            priority.insert(row, providerName)
            priority.compact!
            
            Preferences.instance.providers_priority = priority
            BookProviders.update_priority

            tableView.reloadData
            
            return true
        end
        
        # NSTableView delegation
        
        def tableView_shouldEditTableColumn_row(tableView, col, row)
            false
        end
        
        def tableViewSelectionDidChange(notification)
            provider = _selectedProvider
            unless provider.nil?
                @removeProviderButton.setEnabled(provider.abstract?)
                @setupProviderButton.setEnabled(!provider.prefs.empty?)
            else
                @removeProviderButton.setEnabled(false)
                @setupProviderButton.setEnabled(false)
            end
        end
        
        # NSTabView delegation
        
        def tabView_didSelectTabViewItem(tabView, tabViewItem)
            _updateTitle
        end
        
        #######
        private
        #######
        
        def _updateTitle
            case @tabView.selectedTabViewItem.identifier.to_s
                when 'list_columns'
                    @panel.setTitle(_('List Columns Preferences'))
                when 'providers'
                    @panel.setTitle(_('Providers Preferences'))
            end
        end
        
        def _selectedProvider
            pos = @providersTableView.selectedRow
            pos != -1 ? BookProviders.instance[pos] : nil
        end
        
        def _identifierForButton(button)
            case button.__ocid__
                when @authorsButton.__ocid__
                    :authors
                when @isbnButton.__ocid__
                    :isbn
                when @publisherButton.__ocid__
                    :publisher
                when @bindingButton.__ocid__
                    :binding
                when @ratingButton.__ocid__
                    :rating
                else
                    return
            end
        end
    end
end
end
