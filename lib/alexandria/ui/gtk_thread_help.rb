# -*- ruby -*-
#--
# Copyright (C) 2010 Cathal Mc Ginley
#
# This file is part of GNotions, a GTK+ client for Notions.
#
# Alexandria is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Alexandria is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Alexandria; see the file COPYING. If not, write to the Free
# Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301 USA.
#++

# Taken from a tip on the ruby-gnome2 website
# http://ruby-gnome2.sourceforge.jp/hiki.cgi?tips_threads

# First, force all your your Ruby threads to start from within the
# main loop using the standard Gtk.init method. You can call Gtk.init
# as many times as necessary. For example:
#
# Gtk.init_add do
#   DBus.start_listener
#   false
# end

require 'gtk2'
require 'monitor'

module Gtk
  GTK_PENDING_BLOCKS = []
  GTK_PENDING_BLOCKS_LOCK = Monitor.new
  
  def Gtk.queue &block
    if Thread.current == Thread.main
      block.call
    else
      GTK_PENDING_BLOCKS_LOCK.synchronize do
        GTK_PENDING_BLOCKS << block
      end
    end
  end

# an optional addition from http://www.ruby-forum.com/topic/125038
# "I call Gtk.thread_flush right after killing a thread when I ever
# happen to need kill a thread" -- Mathieu Blondel

#     def self.thread_flush
#         if PENDING_CALLS_MUTEX.try_lock
#             for closure in PENDING_CALLS
#                 closure.call
#             end
#             PENDING_CALLS.clear
#             PENDING_CALLS_MUTEX.unlock
#         end
#     end



  def Gtk.main_with_queue(timeout=100) # millis
    Gtk.timeout_add(timeout) do
      GTK_PENDING_BLOCKS_LOCK.synchronize do
        for block in GTK_PENDING_BLOCKS
          block.call
        end
        GTK_PENDING_BLOCKS.clear
      end
      true
    end
    Gtk.main
  end

 end

# Usage is very simple:

# Start your Gtk application by calling Gtk.main_with_queue rather
# than Gtk.main. The "timeout" argument is in milliseconds, and it is
# the maximum time that can pass until queued blocks get called: 100
# should be fine.

# Whenever you need to queue a call, use Gtk.queue. For example:

