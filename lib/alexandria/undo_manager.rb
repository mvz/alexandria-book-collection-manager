# Copyright (C) 2004-2005 Laurent Sansonetti
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
    class UndoManager
        include Singleton
        include Observable

        attr_reader :actions

        def initialize
            @undo_actions = []
            @redo_actions = []
            @within_undo = @withing_redo = false
        end

        def push(&block)
            (@within_undo ? @redo_actions : @undo_actions) << block
            notify
        end

        def can_undo?
            @undo_actions.length > 0
        end

        def can_redo?
            @redo_actions.length > 0
        end
        
        def undo!
            @within_undo = true
            begin
                action(@undo_actions)
            ensure
                @within_undo = false
            end
        end

        def redo!
            @within_redo = true
            begin
                action(@redo_actions)
            ensure
                @within_redo = false
            end
        end

        #######
        private
        #######

        def action(array)
            action = array.pop
            raise if action.nil?
            action.call
            notify
        end

        def notify
            changed
            notify_observers(self)
        end
    end
end
