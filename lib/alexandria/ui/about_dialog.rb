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
module UI
    class AboutDialog < Gtk::AboutDialog
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent)
            super()
            self.name = Alexandria::TITLE
            self.version = Alexandria::VERSION
            self.copyright = Alexandria::COPYRIGHT
            self.comments = Alexandria::DESCRIPTION
            self.authors = Alexandria::AUTHORS
            self.documenters = Alexandria::DOCUMENTERS
            self.translator_credits = Alexandria::TRANSLATORS.join("\n")
            self.logo = Icons::ALEXANDRIA_SMALL
            self.website = Alexandria::WEBSITE_URL
            self.license = File.read(File.join(Alexandria::Config::DATA_DIR,
                                               "COPYING"))
            self.transient_for = parent
            signal_connect('destroy') { hide }
        end
    end
end
end
