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
# write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301 USA.

require 'glib2'

class String
  
  # Converts this string into the desired charset.
  #
  # Note that this may raise a GLib::ConvertError if the
  # desired_charset cannot accommodate all the characters present in
  # the string, e.g. trying to convert Japanese Kanji to ISO-8859-1
  # will obviously not work.
  def convert(desired_charset, source_data_charset)
    GLib.convert(self, desired_charset, source_data_charset)
  end
end
