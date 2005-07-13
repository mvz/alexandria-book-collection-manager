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
    class Matrix < OSX::NSMatrix
        include OSX
        
        attr_reader :dataSource, :sortDescriptor

        ns_overrides 'keyDown:', 'mouseDown:', 'mouseDragged:', 'mouseUp:', 
                     'menuForEvent:', 'needsPanelToBecomeKey', 'drawRect:'

        def setDataSource(dataSource)
            raise unless dataSource.respondsToSelector?('matrix:objectValueForColumn:row:')
            raise unless dataSource.respondsToSelector?('numberOfCellsInMatrix:')
            raise unless dataSource.respondsToSelector?('matrix:tooltipForColumn:row')
            raise unless dataSource.respondsToSelector?('pasteboardTypeForMatrix:')
            raise unless dataSource.respondsToSelector?('matrix:pasteboardStringForColumn:row:')
            @dataSource = dataSource
        end
        
        def reloadData
            # Unset/disable all cells
            self.numberOfRows.times do |row| 
                self.numberOfColumns.times do |col| 
                    cell = self.cellAtRow_column(row, col)
                    cell.setObjectValue(nil)
                    cell.setEnabled(false)
                end
            end        

            # Reload cells' object value
            row = col = 0
            @dataSource.numberOfCellsInMatrix(self).times do
                cell = self.cellAtRow_column(row, col)
                cell.setObjectValue(@dataSource.matrix_objectValueForColumn_row(self, col, row))
                self.setToolTip_forCell(@dataSource.matrix_tooltipForColumn_row(self, col, row), 
                                        cell)
                cell.setEnabled(true)
                frame = self.cellFrameAtRow_column(row, col)
                col += 1
                if col == self.numberOfColumns
                    col = 0
                    row += 1
                end
            end
            
            self.setNeedsDisplay(true)
        end

        def sortUsingSortDescriptor(sortDescriptor)
            oldDescriptor = @sortDescriptor
            @sortDescriptor = sortDescriptor
            @dataSource.matrix_sortDescriptorDidChange(self, oldDescriptor)
        end

        def mouseDown(event)
            point = self.convertPoint_fromView(event.locationInWindow, nil)
            row = self.rowAtPoint(point)
            col = self.columnAtPoint(point)
            @mouseDownInitialPoint = point

            cell = (row != -1 and col != -1) ? self.cellAtRow_column(row, col) : nil
            @mouseDownOnCell = (cell != nil and cell.isEnabled?)
            shiftPressed = event.modifierFlags & NSShiftKeyMask != 0
            
            if @mouseDownOnCell
                unless self.selectedCells.containsObject?(cell)
                    self.deselectAllCells unless shiftPressed
                    cell.setHighlighted(true)
                else
                    cell.setHighlighted(false) if shiftPressed
                end
                if event.clickCount == 2
                    self.target.performSelector_withObject(self.doubleAction, self) 
                end
            else
                self.deselectAllCells unless shiftPressed
            end
        end
        
        def mouseDragged(event)
            if @mouseDownOnCell
                _performDraggingWithEvent(event)
            else
                # Performing rect selection

                return if @mouseDownInitialPoint.nil?
                point = self.convertPoint_fromView(event.locationInWindow, nil)
                
                if @selectionRect
                    self.setNeedsDisplayInRect(NSInsetRect(@selectionRect, -1, -1))
                end

                @selectionRect = NSRect.new([@mouseDownInitialPoint.x, point.x].min,
                                            [@mouseDownInitialPoint.y, point.y].min,
                                            (@mouseDownInitialPoint.x - point.x).abs,
                                            (@mouseDownInitialPoint.y - point.y).abs)                

                scrollView = self.superview.superview
                scrollPoint = scrollView.convertPoint_fromView(event.locationInWindow, nil)
                scrollRect = scrollView.convertRect_toView(scrollView.frame, nil)

                _invalidateAutoscrollTimerIfNeeded

                unless NSPointInRect(scrollPoint, scrollRect)
                    @autoscrollTimer = NSTimer.scheduledTimerWithTimeInterval(0.08, :target, self,
                                                                                    :selector, '_timedAutoscroll:',
                                                                                    :userInfo, event,
                                                                                    :repeats, true)
                end

                self.deselectAllCells
                selectCellsInRect(@selectionRect)

                self.setNeedsDisplayInRect(NSInsetRect(@selectionRect, -1, -1))
            end
        end
        
        def draggedImage_endedAt_operation(dragImage, point, operation)
            _unsetDragInfo
        end
        
        def mouseUp(event)
            unless @mouseDownOnCell
                if @selectionRect
                    self.setNeedsDisplayInRect(NSInsetRect(@selectionRect, -1, -1))
                    @selectionRect.size.width = @selectionRect.size.height = 0
                    _invalidateAutoscrollTimerIfNeeded
                end
            end
            _unsetDragInfo
        end
        
        def keyDown(event)
            chars = event.charactersIgnoringModifiers
            if chars.length > 0 and chars.characterAtIndex(0) == NSDeleteCharacter
                if self.delegate.respondsToSelector?('matrix:deleteCharacterDown:')
                    self.delegate.matrix_deleteCharacterDown(self, event)
                end
            else
                super_keyDown(event)
            end
        end

        def menuForEvent(event)
            delegate = self.delegate
            if delegate.respondsToSelector?('matrix:popupMenuForEvent:')
                point = self.convertPoint_fromView(event.locationInWindow, nil)
                row = self.rowAtPoint(point)
                col = self.columnAtPoint(point)
                if row != -1 and col != -1
                    cell = self.cellAtRow_column(row, col)
                    unless self.selectedCells.containsObject?(cell)
                        self.deselectAllCells
                        self.selectCellAtRow_column(row, col)
                    end
                else
                    self.deselectAllCells
                end
                delegate.matrix_popupMenuForEvent(self, event)
            else
                super_menuForEvent(event)
            end
        end
        
        def needsPanelToBecomeKey
            # Make sure the view will be activable
            return true
        end

        def drawRect(rect)
            super_drawRect(rect)

            # Draw selection
            if @selectionRect and 
               @selectionRect.size.width > 0 and
               @selectionRect.size.height > 0
                
                drawRect = @selectionRect
                drawRect.origin.x += 0.5
                drawRect.origin.y += 0.5
                
                @selectionFillColor ||= NSColor.colorWithCalibratedRed_green_blue_alpha(0.0, 0.0, 1.0, 0.1)
                @selectionBorderColor ||= NSColor.colorWithCalibratedRed_green_blue_alpha(0.0, 0.0, 1.0, 0.4)
                
                @selectionFillColor.set             
                NSBezierPath.fillRect(drawRect)
                NSBezierPath.setDefaultLineWidth(1.0)
                @selectionBorderColor.set             
                NSBezierPath.strokeRect(drawRect)
            end
        end

        #######
        private
        #######
        
        def _unsetDragInfo
            @mouseDownInitialPoint = nil
            @mouseDownOnCell = nil
        end
        
        def _performDraggingWithEvent(event)
            selectedCells = self.selectedCells.to_a.select { |cell| cell.isEnabled? }
            return if selectedCells.empty?

            # Prepare the pasteboard
            pasteboard = NSPasteboard.pasteboardWithName('Apple CFPasteboard drag')
            pasteboardType = @dataSource.pasteboardTypeForMatrix(self)
            pasteboard.declareTypes_owner(NSArray.arrayWithObject(pasteboardType),
                                          self)
            pasteboardStrings = []

            # Compute selection frame
            selectionFrame = NSRect.new(0, 0, 0, 0)
            selectedCells.each do |cell|
                row = self.rowOfCell(cell)
                col = self.columnOfCell(cell)
                frame = self.cellFrameAtRow_column(row, col)
                selectionFrame = NSUnionRect(selectionFrame, frame)
            end

            # Create a temporary NSImage in which we are going to render 
            # the selected cells.
            image = NSImage.alloc.initWithSize(selectionFrame.size)
            image.setFlipped(self.isFlipped?)
            image.lockFocus
            
            oldRow = oldCol = -1
            drawPoint = NSPoint.new(0, 0)
            xStep = self.cellSize.width + self.intercellSpacing.width
            yStep =  self.cellSize.height + self.intercellSpacing.height
            
            selectedCells.each do |cell|
                row = self.rowOfCell(cell)
                col = self.columnOfCell(cell)
                frame = self.cellFrameAtRow_column(row, col)
                frame = cell.drawingRectForBounds(frame)
                
                # Adjust if necessary
                if oldRow != -1 and oldCol != -1
                    if col > oldCol
                        drawPoint.x += xStep * (col - oldCol)
                    elsif col < oldCol
                        drawPoint.x = 0
                    end

                    if row > oldRow
                        drawPoint.y += yStep * (row - oldRow)
                    elsif row < oldRow
                        drawPoint.y = 0
                    end
                end
 
                frame.origin = drawPoint
                oldRow, oldCol = row, col
                
                # Draw!
                cell.drawWithFrame_inView(frame, self)
            
                # Ask the data source for the pasteboard string at the same time
                pasteboardStrings <<  @dataSource.matrix_pasteboardStringForColumn_row(self, col, row)
            end
            image.unlockFocus
            image.setFlipped(false)
            
            # Render the final drag image (which is a bit transparent)
            dragImage = NSImage.alloc.initWithSize(image.size)
            dragImage.lockFocus
            image.dissolveToPoint_fraction(NSPoint.new(0, 0), 0.5);
            dragImage.unlockFocus

            # Setup the dragging point
            point = dragPoint = self.convertPoint_fromView(event.locationInWindow, nil)
            xDelta = point.x - selectionFrame.origin.x
            dragPoint.x -= xDelta
            yDelta = point.y - selectionFrame.origin.y
            dragPoint.y -= yDelta
            dragPoint.y += dragImage.size.height
            
            # Fill the pasteboard
            pasteboard.setPropertyList_forType(pasteboardStrings, pasteboardType)
            
            # That's all folks!
            self.dragImage(dragImage, :at, dragPoint,
                                      :offset, NSSize.new(0, 0),
                                      :event, event,
                                      :pasteboard, pasteboard,
                                      :source, self,
                                      :slideBack, true)
        end

        def _invalidateAutoscrollTimerIfNeeded
            if @autoscrollTimer
                @autoscrollTimer.invalidate
            end
        end

        def _timedAutoscroll(timer)
            event = timer.userInfo
            self.autoscroll(event)
        end
    end
end
end