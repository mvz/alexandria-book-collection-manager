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
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

require 'alexandria/macui/Icons'
require 'alexandria/macui/Matrix'
require 'alexandria/macui/TableView'
require 'alexandria/macui/RatingField'
require 'alexandria/macui/BooksDataSource'
require 'alexandria/macui/LibrariesDataSource'
require 'alexandria/macui/AboutController'
require 'alexandria/macui/AddBookController'
require 'alexandria/macui/BookInfoController'
require 'alexandria/macui/ImportController'
require 'alexandria/macui/ExportController'
require 'alexandria/macui/PreferencesController'
require 'alexandria/macui/MainController'

module Alexandria
    module UI
        OSX.ns_import :BookIconCell
        OSX.ns_import :RatingCell
        OSX.ns_import :TitledImageCell

        def self.main
            Icons.init
            OSX.NSApplicationMain(0, nil)
        end    
    end    
end