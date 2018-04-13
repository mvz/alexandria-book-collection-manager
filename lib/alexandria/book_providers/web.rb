# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

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
        elsif node.text?
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
