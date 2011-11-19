# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2007 Cathal Mc Ginley
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

require 'alexandria/ui/dialogs/alert_dialog'
# misc_dialogs depends on alert_dialog
require 'alexandria/ui/dialogs/misc_dialogs'
require 'alexandria/ui/dialogs/about_dialog'
require 'alexandria/ui/dialogs/book_properties_dialog_base'
require 'alexandria/ui/dialogs/book_properties_dialog'
require 'alexandria/ui/dialogs/new_book_dialog_manual'
require 'alexandria/ui/dialogs/new_book_dialog'
require 'alexandria/ui/dialogs/preferences_dialog'
require 'alexandria/ui/dialogs/export_dialog'
require 'alexandria/ui/dialogs/import_dialog'
require 'alexandria/ui/dialogs/acquire_dialog'
require 'alexandria/ui/dialogs/smart_library_properties_dialog_base'
require 'alexandria/ui/dialogs/smart_library_properties_dialog'
require 'alexandria/ui/dialogs/new_smart_library_dialog'
require 'alexandria/ui/dialogs/bad_isbns_dialog'
require 'alexandria/ui/dndable'
require 'alexandria/ui/init'
require 'alexandria/ui/ui_manager'
require 'alexandria/ui/listview'
require 'alexandria/ui/iconview'
require 'alexandria/ui/sidepane'

module Alexandria
  module UI
    include Logging
    include GetText
    GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

    class MainApp
      include Logging
      include GetText
      MAX_RATING_STARS = 5
      include Singleton
      attr_accessor :main_app, :libraries, :actiongroup, :appbar, :prefs
      attr_accessor :ui_manager
      def initialize
        log.info { "Starting MainApp" }
        @ui_manager = UIManager.new self
        @actiongroup = @ui_manager.actiongroup
        @appbar = @ui_manager.appbar
        @prefs = @ui_manager.prefs
        @ui_manager.show
      end
    end
  end
end
