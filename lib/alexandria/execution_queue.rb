# Copyright (C) 2005-2006 Laurent Sansonetti
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
# write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301 USA.

require 'thread'

# Provides a way for two threads to communicate via Proc objects.
#
# Thread A can request calls, providing a Proc object and runtime arguments,
# and thread B can iterate through the queue and execute the first call it
# founds.
#
# It is also possible to synchronize the calls (useful if a return value is
# required from the receiving thread).
#
# This class does not depend of the GLib/GTK main loop idea.

module Alexandria
  class ExecutionQueue
    def initialize
      @pending_calls = []
      @pending_retvals = []
      @protect_pending_calls = Mutex.new
      @protect_pending_retvals = Mutex.new
      @id = 0
      @@current_queue = self
    end

    def self.current
      @@current_queue rescue nil
    end

    # For the requesting thread.
    def call(procedure, *args)
      push(procedure, args, false)
    end

    def sync_call(procedure, *args)
      push(procedure, args, true)
    end

    # For the executing thread.
    def iterate
      ary = @protect_pending_calls.synchronize do
        break @pending_calls.pop
      end
      return if ary.nil?
      id, procedure, args, need_retval = ary
      retval = procedure.call(*args)
      if need_retval
        @protect_pending_retvals.synchronize do
          @pending_retvals << [id, retval]
        end
      end
    end

    def stop
      @@current_queue = nil
    end

    #######
    private
    #######

    def push(procedure, args, need_retval=false)
      @protect_pending_calls.synchronize do
        @id += 1
        @pending_calls << [@id, procedure, args, need_retval]
      end
      if need_retval
        while true
          @protect_pending_retvals.synchronize do
            ary = @pending_retvals.find { |id, retval| id == @id }
            if ary
              @pending_retvals.delete(ary)
              return ary[1]
            end
          end
        end
      end
    end
  end
end
