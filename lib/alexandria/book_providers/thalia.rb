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

# http://de.wikipedia.org/wiki/Thalia_%28Buchhandel%29
# Thalia.de bought the Austrian book trade chain Amadeus

# New Tlalia provider, taken from Palatina MetaDataSource and modified
# for Alexandria. (21 Dec 2009)

require 'net/http'
require 'cgi'

module Alexandria
  class BookProviders
    class ThaliaProvider < WebsiteBasedProvider
      include Alexandria::Logging

      SITE = "http://www.thalia.de"
      BASE_SEARCH_URL = "#{SITE}/shop/bde_bu_hg_startseite/suche/?%s=%s" #type,term

      def initialize
        super("Thalia", "Thalia (Germany)")
        # no preferences for the moment
        prefs.read
      end

      def url(book)
        create_search_uri(SEARCH_BY_ISBN, book.isbn)
      end

      def search(criterion, type)
        req = create_search_uri(type, criterion)
        puts req if $DEBUG
        html_data = transport.get_response(URI.parse(req))
        if type == SEARCH_BY_ISBN
          parse_result_data(html_data.body, criterion)
        else          
          results = parse_search_result_data(html_data.body)
          raise NoResultsError if results.empty?
          results.map {|result| get_book_from_search_result(result) }          
        end
      end

      def create_search_uri(search_type, search_term)
        search_type_code = {SEARCH_BY_ISBN => 'sq',
          SEARCH_BY_AUTHORS => 'sa', #Autor
          SEARCH_BY_TITLE => 'st', # Titel
          SEARCH_BY_KEYWORD => 'ssw' # Schlagwort
        }[search_type] or ''
        search_type_code = CGI.escape(search_type_code)
        search_term_encoded = search_term
        if search_type == SEARCH_BY_ISBN
          #search_term_encoded = search_term.as_isbn_13
          search_term_encoded = Library.canonicalise_isbn(search_term) # check this!
        else
          search_term_encoded = CGI.escape(search_term)
        end
        BASE_SEARCH_URL % [search_type_code, search_term_encoded]
      end

      def parse_search_result_data(html)
        doc = html_to_doc(html)
        book_search_results = []
        results_divs = doc / 'div.articlePresentationSearchCH'
        results_divs.each do |div|
          result = {}
          title_link = div % 'div.articleText/h2/a'
          result[:title] = title_link.inner_html
          result[:lookup_url] = title_link['href']
          book_search_results << result
       end
       book_search_results
      end


      def data_from_label(node, label_text)
        label_node = node % "strong[text()*='#{label_text}']"      
        if (item_node = label_node.parent)
          data = ""
          item_node.children.each do |n|
            if n.text?
              data = data + n.to_html
            end
          end
          data.strip
        else
          ""
        end
      end

      def get_book_from_search_result(result)
        log.debug { "Fetching book from #{result[:lookup_url]}" }
        html_data =  transport.get_response(URI.parse(result[:lookup_url]))
        parse_result_data(html_data.body, "noisbn", true)
      end

      def parse_result_data(html, isbn, recursing=false)
        doc = html_to_doc(html)

        results_divs = doc / 'div.articlePresentationSearchCH'
        unless (results_divs.empty?)
          if recursing
            # already recursing, avoid doing so endlessly second time
            # around *should* lead to a book description, not a result
            # list
            return 
          end
          # ISBN-lookup results in multiple results (trying to be
          # useful, such as for new editions e.g. 9780974514055
          # "Programming Ruby" )
          results = parse_search_result_data(html)
          isbn10 = Library.canonicalise_isbn(isbn)
          # e.g. .../dave_thomas/ISBN0-9745140-5-5/ID6017044.html
          chosen = results.first # fallback!
          results.each do |rslt|
            if rslt[:lookup_url] =~ /\/ISBN(\d+[\d-]*)\//
              if $1.gsub('-','') == isbn10
                chosen = rslt
                break
              end
            end
          end
          html_data = transport.get_response(URI.parse(chosen[:lookup_url]))
          return parse_result_data(html_data.body, isbn, true)
        end
          
        begin
          if div = doc % 'div#contentFull'
            title_img = ((div % :h2) / :img).first
            title = title_img["alt"]

            # note, the following img also has alt="von Author, Author..."
            
            if author_h = doc % 'h3[text()*="Mehr von"]' # "More from..." links 
              authors = []
              author_links = author_h.parent / :a
              author_links.each do |a|
                if a['href'] =~ /BUCH\/sa/
                  # 'sa' means search author, there may also be 'ssw' (search keyword) links
                  authors << a.inner_text[0..-2].strip 
                  # NOTE stripping the little >> character here...
                end
              end
            end
            
            item_details = doc % 'ul.itemDataList'
            isbns = []
            isbns << data_from_label(item_details, 'EAN')
            isbns << data_from_label(item_details, 'ISBN')           
            
            year = nil
            date = data_from_label(item_details, 'Erschienen:')
            if (date =~ /([\d]{4})/)
              year = $1.to_i
            end
            
            binding = data_from_label(item_details, 'Einband')
              
            publisher = data_from_label(item_details, 'Erschienen bei:')


            book = Book.new(title, authors, isbns.first, 
                            publisher, year, binding)

            image_url = nil
            if (image_link = doc % 'a[@id=itemPicStart]')
              image_url = image_link['href']
            end

            return [book, image_url]

          end
        rescue Exception => ex
          trace = ex.backtrace.join("\n> ")
          log.warn {"Failed parsing search results for Thalia " +
            "#{ex.message} #{trace}" }
           raise NoResultsError
        end

      end




    end
  end
end
