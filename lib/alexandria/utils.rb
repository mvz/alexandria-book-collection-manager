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

begin
require 'glib2'

class String
    def convert(charset_from, charset_to)
        GLib.convert(self, charset_from, charset_to)
    end
end

rescue LoadError

# We assume there that Ruby/Cocoa is loaded

class String
    def convert(charset_from, charset_to)
        from = OSX::NSString.alloc.initWithString(self)
        encoding = charset_to.nsencoding
        data = from.dataUsingEncoding(encoding)
        OSX::NSString.alloc.initWithData_encoding(data, encoding).to_s
        #self
    end
end

end