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

#require 'zoom'

module Alexandria
class BookProviders
    class Z3950Provider < AbstractProvider
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize
            super("Z39.50")
            prefs.add("hostname", _("Hostname"), "")
            prefs.add("port", _("Port"), 7070)
            prefs.add("database", _("Database"), "")
        end
       
        def search(criterion, type)
            # TODO
            raise "should not be there"
            prefs.read
        end
    end
end
end
