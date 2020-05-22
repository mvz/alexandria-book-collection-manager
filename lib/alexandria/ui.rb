# frozen_string_literal: true

# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2015 Matijs van Zuijlen
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

require "gir_ffi-gtk3"

GirFFI.setup "GdkPixbuf", "2.0"

require "alexandria/ui/icons"
require "alexandria/ui/builder_base"
require "alexandria/ui/completion_models"
require "alexandria/ui/libraries_combo"
require "alexandria/ui/multi_drag_treeview"
require "alexandria/ui/main_app"

module Alexandria
  module UI
    include Logging
    def self.init_icons
      log.info { "Initializing Icons" }
      Icons.init
    end

    def self.start_main_app
      log.debug { "==========================" }
      log.info { "Starting MainApp" }
      log.debug { "==========================" }
      MainApp.instance
    end

    def self.start_gtk
      log.debug { "====================================" }
      log.info { "Starting Gtk" }
      log.debug { "====================================" }
      Gtk.main
    end

    def self.main
      init_icons
      start_main_app
      start_gtk
    end
  end
end
