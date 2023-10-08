# frozen_string_literal: true

# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2007 Cathal Mc Ginley
# Copyright (C) 2011 Matijs van Zuijlen
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

require "alexandria/ui/alert_dialog"
require "alexandria/ui/about_dialog"
require "alexandria/ui/book_properties_dialog_base"
require "alexandria/ui/book_properties_dialog"
require "alexandria/ui/new_book_dialog_manual"
require "alexandria/ui/new_book_dialog"
require "alexandria/ui/preferences_dialog"
require "alexandria/ui/export_dialog"
require "alexandria/ui/import_dialog"
require "alexandria/ui/acquire_dialog"
require "alexandria/ui/smart_library_properties_dialog_base"
require "alexandria/ui/smart_library_properties_dialog"
require "alexandria/ui/new_smart_library_dialog"
require "alexandria/ui/bad_isbns_dialog"
require "alexandria/ui/dndable"
require "alexandria/ui/init"
require "alexandria/ui/ui_manager"
require "alexandria/ui/listview"
require "alexandria/ui/icon_view_manager"
require "alexandria/ui/sidepane_manager"

module Alexandria
  module UI
    include Logging
    include GetText
    GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

    class MainApp
      include Logging
      include GetText
      include Singleton
      attr_accessor :main_app, :libraries, :actiongroup, :appbar, :prefs, :ui_manager

      def initialize
        log.info { "Starting MainApp" }
        @ui_manager = UIManager.new self
        @actiongroup = @ui_manager.actiongroup
        @appbar = @ui_manager.appbar
        @prefs = @ui_manager.prefs
        @main_app = @ui_manager.main_app
        @ui_manager.show
      end
    end
  end
end
