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

class Time
    def self.parse(*arg)
        date = nil
        begin
            date = super
        rescue ArgumentError
            if arg.length == 1
                # Handle the 'XXXX' case (year-only)
                if /^(\d\d\d\d)$/.match(arg.first)
                    date = super("01 January, %s" % arg.first)

                # Handle the 'XXXX, YYYY' (month name and year)
                elsif /^(\c+)\s*,\s*(\d\d\d\d)$/.match(arg.first)
                    begin
                        date = super("01 " + arg.first)
                    rescue ArgumentError
                    end
                end
            end
        end
        return date
    end
end

begin
require 'glib2'

class String
    def convert(charset_from, charset_to)
        GLib.convert(self, charset_from, charset_to)
    end
end

rescue LoadError

# We assume that Ruby/Cocoa is loaded there

#require 'iconv'

class String
    def to_utf8_nsstring
        # This should be writen in ObjC in order to catch the ObjC exception if the
        # string could not be converted to UTF8.
        (OSX::NSString.stringWithUTF8String(self) or self)
    end

    def convert(charset_from, charset_to)
        # Do nothing for the moment...
        self
    end
=begin
        return OSX::NSString.stringWithUTF8String(self)
        x = Iconv.iconv(charset_to, charset_from, self).first
        p "#{self} -> #{x}"
        return x
        #p charset_from, charset_to
        #return self

        from = OSX::NSString.alloc.initWithString(self)
        encoding = charset_to.nsencoding
        encoding = OSX::NSUnicodeStringEncoding
        data = from.dataUsingEncoding(encoding)
        s = OSX::NSString.alloc.initWithData_encoding(data, encoding).to_s
        s
        #self
    end
=end
end

end
