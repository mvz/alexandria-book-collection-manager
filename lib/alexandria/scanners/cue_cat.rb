# frozen_string_literal: true

# Copyright (C) 2005-2006 Christopher Cyll
# Copyright (C) 2011, 2014-2022 Matijs van Zuijlen
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

require "alexandria/scanners"

module Alexandria
  module Scanners
    class CueCat
      include Logging

      def name
        "CueCat"
      end

      def display_name
        "CueCat"
      end

      # Checks if data looks like cuecat input
      def match?(data)
        data = data.chomp
        return false if data[-1] != "."

        fields = data.split(".")
        return false if fields.size != 4
        return false if fields[2].size != 4

        true
      end

      # Decodes CueCat input into ISBN
      # The following code is adapted from Skip Rosebaugh's public
      # domain perl implementation.
      def decode(data)
        data = data.chomp
        fields = data.split(".")
        fields.shift # First part is gibberish
        fields.shift # Second part is cuecat serial number
        type, code = fields.map { |field| decode_field(field) }

        if type == "IB5"
          type = "IBN"
          code = code[0, 13]
        end

        if Library.valid_upc? code
          isbn13 = Library.canonicalise_ean(code)
          code = isbn13
          type = "IBN"
        end

        return code if type == "IBN"

        raise format(_("Don't know how to handle type %<type>s (barcode: %<code>s)"),
                     type: type, code: code)
      end

      private

      def decode_field(encoded)
        seq = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-"

        chars   = encoded.chars
        values  = chars.map { |c| seq.index(c) }

        padding = pad(values)
        result  = calc(values)
        result[0, result.length - padding]
      end

      def calc(values)
        result = ""
        until values.empty?
          num = ((values[0] << 6 | values[1]) << 6 | values[2]) << 6 | values[3]
          result += ((num >> 16) ^ 67).chr
          result += ((num >> 8 & 255) ^ 67).chr
          result += ((num & 255) ^ 67).chr

          values = values[4, values.length]
        end
        result
      end

      def pad(array)
        length = array.length % 4

        if length.nonzero?
          raise _("Error parsing CueCat input") if length == 1

          length = 4 - length
          length.times { array.push(0) }
        end

        length
      end
    end

    # Register a cuecat scanner with the Scanner Registry
    register CueCat.new
  end
end
