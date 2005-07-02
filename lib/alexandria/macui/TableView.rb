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
    class TableView < OSX::NSTableView
        include OSX

        ns_overrides 'keyDown:', 'mouseDown:', 'menuForEvent:'

        def keyDown(event)
            chars = event.charactersIgnoringModifiers
            if chars.length > 0 and chars.characterAtIndex(0) == NSDeleteCharacter
                if self.delegate.respondsToSelector?('tableView:deleteCharacterDown:')
                    self.delegate.tableView_deleteCharacterDown(self, event)
                end
            else
                super_keyDown(event)
            end
        end
        
        def _startEditingWithEvent(event)
            point = self.convertPoint_fromView(event.locationInWindow, nil)
            row = self.rowAtPoint(point)
            col = self.columnAtPoint(point)
            return if row == -1 or col == -1

            @lastEditClickEvent = nil

            if self.selectedRow != row
                self.selectRowIndexes_byExtendingSelection(NSIndexSet.indexSetWithIndex(row),
                                                           false)
            end
            self.editColumn(col, :row, row,
                                 :withEvent, event,
                                 :select, true)
        end
        
        def mouseDown(event)
            p event.oc_type
            point = self.convertPoint_fromView(event.locationInWindow, nil)
            row = self.rowAtPoint(point)
            col = self.columnAtPoint(point)
            if row == -1 or col == -1
                super_mouseDown(event)
                return
            end

            # simple click
            if event.clickCount == 1
                oldSelectedRow = self.selectedRow
                super_mouseDown(event)
                delegate = self.delegate
                if delegate.respondsToSelector?('tableView:shouldEditTableColumn:row:')
                    if oldSelectedRow == self.selectedRow and
                       delegate.tableView_shouldEditTableColumn_row(self,
                                                                    self.tableColumns.objectAtIndex(col),
                                                                    row)

                        NSObject.cancelPreviousPerformRequestsWithTarget(self, :selector, :_startEditingWithEvent,
                                                                               :object, event)
                        @lastEditClickEvent = event
                        self.performSelector(:_startEditingWithEvent, :withObject, event,
                                                                      :afterDelay, 0.5)                                                                    
                    end
                end
                
                if delegate.respondsToSelector?('tableView:mouseDown:oldSelectedRow:')
                    delegate.tableView_mouseDown_oldSelectedRow(self, event, oldSelectedRow)
                end
            # double (or more) click 
            else
                self.selectRowIndexes_byExtendingSelection(NSIndexSet.indexSetWithIndex(row),
                                                           false)
                if @lastEditClickEvent
                    NSObject.cancelPreviousPerformRequestsWithTarget(self, :selector, :_startEditingWithEvent,
                                                                           :object, @lastEditClickEvent)
                end
                self.target.send(self.doubleAction.gsub(/:/, '_'))
            end
        end
        
        def menuForEvent(event)
            delegate = self.delegate
            if delegate.respondsToSelector?('tableView:popupMenuForEvent:')
                point = self.convertPoint_fromView(event.locationInWindow, nil)
                row = self.rowAtPoint(point)
                col = self.columnAtPoint(point)
                if row != -1 and col != -1
                    unless self.selectedRowIndexes.containsIndex?(row)
                        self.selectRowIndexes_byExtendingSelection(NSIndexSet.indexSetWithIndex(row),
                                                                   false)
                    end
                else
                    self.deselectAll(nil)
                end
                delegate.tableView_popupMenuForEvent(self, event)
            else
                super_menuForEvent(event)
            end
        end
        
        def setHidden_forColumnWithIdentifier(state, identifier)
            @hiddenColumns ||= {}
            identifier = identifier.to_s.strip
            if state 
                return if @hiddenColumns.key?(identifier)
                tableColumn = self.tableColumnWithIdentifier(identifier)
                return unless tableColumn
                pos = self.columnWithIdentifier(identifier)
                @hiddenColumns[identifier] = tableColumn
                self.removeTableColumn(tableColumn)
            else
                tableColumn = @hiddenColumns[identifier]
                return unless tableColumn
                @hiddenColumns.delete(identifier)
                self.addTableColumn(tableColumn)
            end
        end
        
        def isColumnWithIdentifierHidden(identifier)
            @hiddenColumns ||= {}
            identifier = identifier.to_s.strip
            @hiddenColumns.key?(identifier)
        end
    end
end
end