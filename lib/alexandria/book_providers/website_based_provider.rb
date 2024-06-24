# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

# By default, Nokogiri will configure libxml2 to use Ruby's memory
# management functions. This leads to the following sequence of events:
#
# - GC starts
# - Ruby/GNOME traverses the known GObject objects
# - Ruby/GNOME fetches properties for all objects
# - One of the properties (I do not know which one) gets initialized to its default value
# - As part of this process some SVG is parsed
# - Do do this, some memory needs to be allocated
# - Ruby does not want memory to be allocated during GC
# - The process crashes
#
# To avoid this, before loading nokogiri, set an environment variable that
# tells Nokogiri to leave libxml2's memory management alone.
#
# See https://github.com/sparklemotion/nokogiri/blob/main/adr/2023-04-libxml-memory-management.md
#
ENV["NOKOGIRI_LIBXML_MEMORY_MANAGEMENT"] = "default"

require "nokogiri"
require "htmlentities"

module Alexandria
  class BookProviders
    class WebsiteBasedProvider < GenericProvider
      def initialize(name, fullname = nil)
        super
        @htmlentities = HTMLEntities.new
      end

      def html_to_doc(html, source_data_charset = "ISO-8859-1")
        html.force_encoding source_data_charset
        utf8_html = html.encode("utf-8")
        normalized_html = @htmlentities.decode(utf8_html)
        Nokogiri.parse(normalized_html)
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
            node_text.strip.squeeze(" ")
          end
        end
        # node.inner_html.strip
      end
    end
  end
end
