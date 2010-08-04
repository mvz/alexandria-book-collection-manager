# -*- ruby -*-
#
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

# http://en.wikipedia.org/wiki/Barnes_&_Noble

# New BarnesAndNoble provider, taken from the Palatina MetaDataSource
# and modified to fit the structure of Alexandria book providers.
# Completely rewritten by Cathal Mc Ginley (18 Dec 2009)

# NOTE: this modified version is based on the Alexandria WorldCat provider.


require 'cgi'
require 'alexandria/net'

module Alexandria
  class BookProviders

    class BarnesAndNobleProvider < WebsiteBasedProvider
      include Alexandria::Logging

      SITE = "http://www.barnesandnoble.com"

      BASE_ISBN_SEARCH_URL = "http://search.barnesandnoble.com/books" +
        "/product.aspx?ISBSRC=Y&ISBN=%s"

      BASE_SEARCH_URL = "http://search.barnesandnoble.com/booksearch" +
        "/results.asp?%s=%s" # type, term

      def initialize()
        super("BarnesAndNoble", "BarnesAndNoble")
        @agent = nil
        prefs.read
      end

      def agent      
        unless @agent
          @agent = Alexandria::WWWAgent.new
        end        
        @agent
      end


      def fetch_redirectly(uri_str, limit = 5)
        raise NoResultsError, 'HTTP redirect too deep' if limit == 0       
        response = agent.get(uri_str)
        if limit < 10
          sleep 0.1
          puts "Redirectly :: #{uri_str}"
        else
          puts "Fetching   :: #{uri_str}"
        end
        puts response.inspect
        case response
        when Net::HTTPSuccess     then response
        when Net::HTTPRedirection then fetch_redirectly(response['Location'], (limit - 1))
        else
          response.error!
        end
      end

      def search(criterion, type)
        req = create_search_uri(type, criterion)
        puts "Requesting #{req}" if $DEBUG
        html_data = fetch_redirectly(req)

        if type == SEARCH_BY_ISBN
          parse_result_data(html_data.body, criterion)
        else
          results = parse_search_result_data(html_data.body)
          raise NoResultsError if results.empty?

          results.map {|result| get_book_from_search_result(result) }          
        end

      end

      def url(book)
        begin
          create_search_uri(SEARCH_BY_ISBN, book.isbn)
        rescue Exception => ex
          log.warn { "Cannot create url for book #{book}; #{ex.message}" }
          nil
        end
      end

      def create_search_uri(search_type, search_term)
        search_type_code = { SEARCH_BY_AUTHORS => 'ATH',
           SEARCH_BY_TITLE => 'TTL',
          SEARCH_BY_KEYWORD => 'WRD'    # SEARCH_BY_PUBLISHER => 'PBL' # not implemented
        }[search_type] or ''
        if search_type == SEARCH_BY_ISBN
          BASE_ISBN_SEARCH_URL % Library.canonicalise_ean(search_term) # isbn-13
        else
          search_term_encoded = CGI.escape(search_term)
          BASE_SEARCH_URL % [search_type_code, search_term_encoded]
        end
      end

      def get_book_from_search_result(result)
        log.debug { "Fetching book from #{result[:url]}" }
        html_data =  transport.get_response(URI.parse(result[:url]))
        parse_result_data(html_data.body)
      end

     def parse_search_result_data(html)
       doc = html_to_doc(html)
       book_search_results = []
       begin
         result_divs = doc / 'div[@class*="book-container"]'
         result_divs.each do |div|
           result = {}
           #img = div % 'div.book-image/a/img'
           #result[:image_url] = img['src'] if img
           title_header = div % 'h2'
           title_links = title_header / 'a'
           result[:title] = title_links.first.inner_text
           result[:url] = title_links.first['href']

           book_search_results << result
        end
      rescue Exception => ex
        trace = ex.backtrace.join("\n> ")
        log.warn {"Failed parsing search results for Barnes & Noble " +
          "#{ex.message} #{trace}" }
      end
       book_search_results  
      end

     def parse_result_data(html, search_isbn=nil, recursing=false)
       doc = html_to_doc(html)
       begin
         book_data = {}
         title_header = doc % '//div.wgt-productTitle/h1'
         if title_header
           title = ""
           title_header.children.each do |node|
             if node.text?
               title += " " + node.to_s
             end
           end
           title.strip!
           if title.empty?
             log.warn { "Unexpectedly found no title in BarnesAndNoble lookup" }
             raise NoResultsError
           end
           book_data[:title] = title.strip.squeeze(' ')
           subtitle_span = title_header % 'span.subtitle'
           if subtitle_span
             book_data[:title] += " #{subtitle_span.inner_text}"
           end
         end

         isbn_links = doc / '//a.isbn-a'
         isbns = isbn_links.map{|a| a.inner_text}
         book_data[:isbn] =  Library.canonicalise_ean(isbns.first)


         authors = []
         author_links = title_header / 'a[@href*="ATH"]'
         author_links.each do |a|
           authors << a.inner_text
         end
         book_data[:authors] = authors

         publisher_item = doc % 'li.publisher'
         if publisher_item
           publisher_item.inner_text =~ /Publisher:\s*(.+)/
           book_data[:publisher] = $1
         end

        date_item = doc % 'li.pubDate'
        if date_item
          date_item.inner_text =~ /Date: ([^\s]*)\s*([\d]{4})/
          year = $2.to_i if $2
          book_data[:publication_year] = year
        end

         book_data[:binding] = ""
         format_list_items = doc / '//div.col-one/ul/li'
         format_list_items.each do |li|
           if li.inner_text =~ /Format:\s*(.*),/             
             book_data[:binding] = $1
           end
         end

         image_url = nil
         product_image_div = doc % 'div#product-image'
         if product_image_div
           images = product_image_div / 'img'
           if images.size == 1
             book_data[:image_url] = images.first['src']
           else
             if images.first['src'] =~ /see_inside.gif/
               # the first image is the "See Inside!" label               
               book_data[:image_url] = images[1]['src']
             else
               book_data[:image_url] = images.first['src']
             end
           end
         end

         book = Book.new(book_data[:title], book_data[:authors], 
                         book_data[:isbn], book_data[:publisher],
                         book_data[:publication_year],
                         book_data[:binding])
         return [book, book_data[:image_url]]
      rescue Exception => ex
         raise ex if ex.instance_of? NoResultsError
         trace = ex.backtrace.join("\n> ")
         log.warn {"Failed parsing search results for BarnesAndNoble " +
           "#{ex.message} #{trace}" }
         raise NoResultsError
      end

     end

   end # class BarnesAndNobleProvider
 end # class BookProviders
end # module Alexandria
