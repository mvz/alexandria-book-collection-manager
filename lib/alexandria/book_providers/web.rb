# -*- ruby -*-
#
# Copyright (C) 2009 Cathal Mc Ginley
# Copyright (C) 2014 Matijs van Zuijlen
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

require 'hpricot'
require 'htmlentities'

module Alexandria
  class BookProviders
    class WebsiteBasedProvider < GenericProvider
      def initialize(name, fullname = nil)
        super(name, fullname)
        @htmlentities = HTMLEntities.new
      end

      def html_to_doc(html, source_data_charset = 'ISO-8859-1')
        html.force_encoding source_data_charset
        utf8_html = html.encode('utf-8')
        normalized_html = @htmlentities.decode(utf8_html)
        Hpricot(normalized_html)
      end

      ## from Palatina
      def text_of(node)
        if node.nil?
          nil
        else
          if node.text?
            node.to_html
          elsif node.elem?
            if node.children.nil?
              nil
            else
              node_text = node.children.map { |n| text_of(n) }.join
              node_text.strip.squeeze(' ')
            end
          end
          # node.inner_html.strip
        end
      end
    end
  end
end
