# Copyright (C) 2004-2006 Laurent Sansonetti
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

require 'gdk_pixbuf2'
require 'libglade2'
require 'gnome2'

require 'alexandria/ui/icons'
require 'alexandria/ui/glade_base'
require 'alexandria/ui/completion_models'
require 'alexandria/ui/libraries_combo'
require 'alexandria/ui/multi_drag_treeview'
require 'alexandria/ui/main_app'


module Pango
  def self.ellipsizable?
    @ellipsizable ||= Pango.constants.include?('ELLIPSIZE_END')
  end
end

module Alexandria
  module UI
    def self.main
      puts "Initializing app_datadir..." if $DEBUG
      Gnome::Program.new('alexandria', VERSION).app_datadir =
        Config::MAIN_DATA_DIR
      puts "Initializing Icons..." if $DEBUG
      Icons.init
      puts "Starting MainApp..." if $DEBUG
      MainApp.new
      puts "Starting Gtk.main..." if $DEBUG
      Gtk.main
    end
  end
end
