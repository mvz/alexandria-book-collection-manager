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

require 'gdk_pixbuf2'
require 'libglade2'
require 'gnome2'

require 'alexandria/ui/icons'
require 'alexandria/ui/glade_base'
require 'alexandria/ui/alert_dialog'
require 'alexandria/ui/about_dialog'
require 'alexandria/ui/book_properties_dialog_base'
require 'alexandria/ui/book_properties_dialog'
require 'alexandria/ui/new_book_dialog_manual'
require 'alexandria/ui/new_book_dialog'
require 'alexandria/ui/preferences_dialog'
require 'alexandria/ui/export_dialog'
require 'alexandria/ui/import_dialog'
require 'alexandria/ui/main_app'

module Alexandria
module UI
    def self.main
        Gnome::Program.new(TITLE, VERSION)
        Icons.init
        MainApp.new
        Gtk.main
    end
end
end
