# Copyright (C) 2004 Laurent Sansonetti
# Copyright (C) 2007 Laurent Sansonetti and Marco Costantini
# Copyright (C) 2009 Cathal Mc Ginley
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

# Adapted code from 'bn.rb' (I hope that it works!)

# Almost completely rewritten by Cathal Mc Ginley (21 Feb 2009)
# based on the new code for Palatina

require 'net/http'
require 'cgi'
require 'hpricot'

module Alexandria
  class BookProviders
    class SicilianoProvider < GenericProvider
      include Logging

      SITE = "http://www.siciliano.com.br"
      BASE_SEARCH_URL = "#{SITE}/pesquisaweb/pesquisaweb.dll/pesquisa?" +
      "&FIL_ID=102" +
      "&PALAVRASN1=%s" + # search term
      "&FILTRON1=%s" + # search type
      "&ESTRUTN1=0301&ORDEMN2=E"

      def initialize
        super("Siciliano", "Livraria Siciliano (Brasil)")
        # no preferences for the moment
      end

      def get_book_from_search_result(result)
        log.debug { "Fetching book from #{result[:url]}" }
        html_data = transport.get(URI.parse(result[:url]))
        parse_result_data(html_data, result)
      end


      def search(criterion, type)
        criterion = criterion.convert("ISO-8859-1", "UTF-8") # still needed??
        trying_again = false
        begin
          req = create_search_uri(type, criterion, trying_again)
          log.debug {"#{name} #{trying_again ? 'retrying ':''}request = #{req}"}
          data = transport.get(URI.parse(req))
          results = parse_search_result_data(data)
          raise NoResultsError if results.empty?


          if type == SEARCH_BY_ISBN
            get_book_from_search_result(results.first)
          else
            results.map {|result| get_book_from_search_result(result) }
          end

        rescue NoResultsError => err
          if (type == SEARCH_BY_ISBN) and (trying_again == false)
            trying_again = true
            retry
          else
            raise err
          end
        end

       
      end

      # the new Siciliano website no longer has direct links to books by their ISBN
      # (the permalink now seems to be based on the product id)
      def url(book)
        nil
      end


      private

      def create_search_uri(search_type, search_term, trying_again=false)
        search_type_code = {SEARCH_BY_ISBN => 'G',
          SEARCH_BY_TITLE => 'A',
          SEARCH_BY_AUTHORS => 'B',
          SEARCH_BY_KEYWORD => 'X'
        }[search_type] or 'X'
        search_term_encoded = search_term
        if search_type == SEARCH_BY_ISBN
          if trying_again
            # on second attempt, try ISBN-10...
            search_term_encoded = Library.canonicalise_isbn(search_term) # isbn-10
          else
            # search by ISBN-13 first
            search_term_encoded = Library.canonicalise_ean(search_term) # isbn-13
          end          
        else
          search_term_encoded = CGI.escape(search_term)
        end

        BASE_SEARCH_URL % [search_term_encoded, search_type_code]
      end


    def parse_search_result_data(html)

      # The layout...
      # td[@class="normal"]
      #   span[@class="vitrine_nome_produto"]
      #      a (title and link to 'product page')
      #   br
      #   TEXT --> author / publisher
      #   br
      #   div[@class="vitrine_preco_por"] (price info)

      doc = Hpricot(html)
      book_search_results = []
      # each result will be a dict with keys :title, :author, :publisher, :url

      td_cells = doc.search('td[@class=normal]/span[@class="vitrine_nome_produto"]/..')
      td_cells.each do |td|
        begin
          result = {}

          # author & publisher
          author_publisher = ''
          td.children.each do |node|
            author_publisher += node.to_s if node.text?
            author_publisher.strip!
            break unless author_publisher.empty?
          end
          author, publisher = author_publisher.split('/')
          result[:author] = author.strip if author
          result[:publisher] = publisher.strip if publisher

          # title & url
          link = td%'a'
          result[:title] = link.inner_text.strip
          link_to_description = link['href']
          result[:url] =  "http://www.siciliano.com.br/#{link_to_description}"

          book_search_results << result
        rescue Exception => ex
          trace = ex.backtrace.join("\n> ")
          log.error { "Failed parsing Siciliano search page #{ex.message}\n#{trace}" }
        end
      end

      book_search_results
    end



    def parse_result_data(html, search_result)
      # checked against Siciliano website 21 Feb 2009

      begin

        #html = html.convert('UTF-8', 'ISO-8859-1')
        doc = Hpricot(html)

        # title
        title_td = doc%'td.produto_miolo'
        title = first_non_empty_text_node(title_td)

        author_spans = doc/'span.rotulo'
        authors = []
        author_spans.each do |span|
          authors << span.inner_text.strip
        end

        ## synopsis_div = doc%'div#sinopse'

        details_div = doc%'div#caracteristica'
        details = string_array_to_map(lines_of_text_as_array(details_div))

        # ISBN
        isbn =  details["ISBN"]
        ## ean = details["CdBarras"]

        translator = details["Tradutor"]
        if translator
          authors << translator
        end

        
        binding = details["Acabamento"]

        publisher = search_result[:publisher]

        # publish year
        publish_year = nil
        edition = details["Edio"]
        if edition
          if edition =~ /([12][0-9]{3})/ # publication date
            publish_year = $1.to_i
          end
        end

        #cover
        #ImgSrc[1]="/imagem/imagem.dll?pro_id=1386929&PIM_Id=658849";
        image_urls = []
        (doc/"script").each do |script|
          script.children.each do |ch|
            ch_text = ch.to_s
            if ch_text =~ /ImgSrc\[[\d]\]="(.+)";/
              image_urls << "#{SITE}/#{$1}"
            end
          end
        end
      
        book = Book.new(title, authors, isbn, publisher, publish_year, binding)
        result =  [book, image_urls.first]        
        return result
      rescue Exception => ex
        trace = ex.backtrace.join("\n> ")
        log.error { "Failed parsing Siciliano product page #{ex.message}\n#{trace}" }
        return nil        
      end
    end
    
    def first_non_empty_text_node(elem)
      text = ''
      elem.children.each do |node|
        next unless node.text?
        text = node.to_s.strip
        break unless text.empty?
      end
      text
    end

    def lines_of_text_as_array(elem)
      lines = []
      current_text = ''
      elem.children.each do |e|
        if e.text?
          current_text += e.to_s
        elsif e.name == 'br'
          lines << current_text.strip
          current_text = ''
        else
          current_text += e.inner_text
        end
      end
      lines << current_text.strip
      lines.delete('')
      lines
    end

    def string_array_to_map(arr)
      map = {}
      arr.each do |str|
        key, val = str.split(':')
        # a real hack for not handling encoding properly :^)
        map[key.gsub(/[^a-zA-z]/, '')] = val.strip()
      end
      map
    end

    #def binding_type(binding) # portuguese string
    #  {"brochura" => :paperback,
    #    "encadernado" => :hardback}[binding.downcase] or :unknown
    #end


    end
  end
end
