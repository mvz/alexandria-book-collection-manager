# -*- ruby -*-

require 'hpricot'
require 'htmlentities'

module Alexandria
  class BookProviders

    class WebsiteBasedProvider < GenericProvider

      def initialize(name, fullname=nil)
        super(name, fullname)
        @htmlentities = HTMLEntities.new
      end

      def html_to_doc(html, source_data_charset="ISO-8859-1")
        if source_data_charset == "UTF-8"
          utf8_html = html
        else
          utf8_html = Iconv.conv("UTF-8", source_data_charset, html)
        end
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
              return nil
            else
              node_text = node.children.map {|n| text_of(n) }.join
              node_text.strip.squeeze(' ')
            end
          end
          #node.inner_html.strip
        end
      end


    end
  end
end
