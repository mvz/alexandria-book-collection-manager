# Copyright (C) 2005-2006 Christopher Cyll
# Copyright (C) 2008 Cathal Mc Ginley
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

require 'alexandria/scanners'

module Alexandria
  module Scanners

    # A simple keyboard-wedge style barcode scanner which presents
    # scan data as if typed from a keyboard. (Modified CueCats act
    # like this.)
    class KeyboardWedge

      def name()
        return "KeyboardWedge"
      end

      def display_name
        "Keyboard Wedge"
      end

      # Checks if data looks like a completed scan
      def match?(data)
        data.gsub!(/\s/, '')
        (data =~ /[0-9]{12,18}/) || (data =~ /[0-9]{9}[0-9Xx]/)
      end

      # Gets the essential 13-digits from an ISBN barcode (EAN-13)
      def decode(data)
        data.gsub!(/\s/, '')
        if data.length == 10
          return data
        elsif data.length >= 13
          return data[0,13]
        else
          raise "Unknown scan data #{data}"
        end
      end

      private


    end

    # Register the wedge scanner with the Scanner Registry
    Registry.push(KeyboardWedge.new())

  end
end
