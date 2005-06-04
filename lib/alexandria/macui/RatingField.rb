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
    class RatingField < OSX::NSControl
        include OSX
        
        ns_overrides 'initWithFrame:', 'mouseDown:', 'mouseDragged:'
        
        attr_accessor :delegate
        
        def initWithFrame(rect)
            super_initWithFrame(rect)
            @cell = RatingCell.alloc.init
            @cell.setObjectValue(NSNumber.numberWithUnsignedInt(0))
            setCell(@cell)
            @delegate = nil
            return self
        end
        
        def mouseDown(event)
            _setValueFromEvent(event)
        end
        
        def mouseDragged(event)
            _setValueFromEvent(event)
        end

        #######
        private
        #######

        def _setValueFromEvent(event)
            point = self.convertPoint_fromView(event.locationInWindow, nil)
            rating = RatingCell.valueForPoint(point)
            if @cell.objectValue.unsignedIntValue != rating
                @cell.setObjectValue(NSNumber.numberWithUnsignedInt(rating))
                if @delegate != nil and @delegate.respond_to?(:ratingField_ratingDidChange)
                    @delegate.ratingField_ratingDidChange(self, rating)
                end
            end
        end
    end
end
end