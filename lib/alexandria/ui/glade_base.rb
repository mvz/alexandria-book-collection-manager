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
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

module Alexandria
module UI
    class GladeBase
        def initialize(filename)
            file = File.join(Alexandria::Config::DATA_DIR, 'glade', filename)
            glade = GladeXML.new(file, nil, Alexandria::TEXTDOMAIN) { |handler| method(handler) }
            glade.widget_names.each do |name|
                begin
                    instance_variable_set("@#{name}".intern, glade[name])
                rescue
                end
            end
        end
    end
end
end
