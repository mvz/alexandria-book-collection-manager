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

# http://en.wikipedia.org/wiki/WorldCat
# See http://www.oclc.org/worldcat/policies/terms/

# New WorldCat provider, taken from the Palatina MetaDataSource and
# modified to fit the structure of Alexandria book providers.
# (25 Feb 2009)
#
# Updated from Palatina, to reflect changes in the worldcat website.
# (1 Sep 2009)


require 'cgi'
require 'alexandria/net'

module Alexandria
  class BookProviders
    class WorldCatProvider < WebsiteBasedProvider
      include Alexandria::Logging

      SITE = "http://www.worldcat.org"
      BASE_SEARCH_URL = "#{SITE}/search?q=%s%s&qt=advanced" # type, term

      def initialize()
        super("WorldCat", "WorldCat")
        #prefs.add("enabled", _("Enabled"), true, [true,false])
        prefs.read
      end

      def search(criterion, type)
        #puts create_search_uri(type, criterion)
        req = create_search_uri(type, criterion)
        puts req if $DEBUG
        html_data = transport.get_response(URI.parse(req))
        # Note: I tried to use Alexandria::WWWAgent, 
        #       but this caused failures here (empty pages...)
        #       find out how the requests differ

        #puts html_data.class
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


      private 

      def create_search_uri(search_type, search_term)
        search_type_code = {SEARCH_BY_ISBN => 'isbn:',
          SEARCH_BY_AUTHORS => 'au:',
          SEARCH_BY_TITLE => 'ti:',
          SEARCH_BY_KEYWORD => ''
        }[search_type] or ''
        search_type_code = CGI.escape(search_type_code)
        search_term_encoded = search_term # TODO, remove attack stuff
        if search_type == SEARCH_BY_ISBN
          search_term_encoded = Library.canonicalise_ean(search_term) # isbn-13
        else
          search_term_encoded = CGI.escape(search_term)
        end
        BASE_SEARCH_URL % [search_type_code, search_term_encoded]
      end

      def get_book_from_search_result(result)
        log.debug { "Fetching book from #{result[:url]}" }
        html_data =  transport.get_response(URI.parse(result[:url]))
        parse_result_data(html_data.body)
      end



      def parse_search_result_data(html)
        doc = html_to_doc(html, "UTF-8")
        book_search_results = []
        begin
          result_cells = doc/'td.result/div.name/..'
          #puts result_cells.length
          result_cells.each do |td|
            type_icon = (td%'div.type/img.icn')
            next unless (type_icon and type_icon['src'] =~ /icon-bks/)
            name_div = td%'div.name'
            title = name_div.inner_text
            anchor = name_div%:a
            if anchor
              url = anchor['href']
            end
            lookup_url = "#{SITE}#{url}"
            result = {}
            result[:title] = title
            result[:url] = lookup_url

            book_search_results << result
          end
        rescue Exception => ex
          trace = ex.backtrace.join("\n> ")
          log.warn {"Failed parsing search results for WorldCat " +
            "#{ex.message} #{trace}" }
        end
        book_search_results  
      end



    def parse_result_data(html, search_isbn=nil, recursing=false)
      doc = html_to_doc(html, "UTF-8")
      
      begin
        if doc%'div#div-results-none'
          log.debug { "WorldCat reports no results" }
          raise NoResultsError
        end


        if doc % 'table.table-results'
          if recursing
            log.warn { "Infinite loop prevented redirecting through WorldCat" }
            raise NoResultsError
          end
          log.info { "Found multiple results for lookup: checking each" }
          search_results = parse_search_result_data(html)
          book = nil
          cover_url = nil
          first_result = nil
          search_results.each do |rslt|
            #rslt = search_results.rslt
            log.debug { "checking #{rslt[:url]}" }
            rslt2 = transport.get_response(URI.parse(rslt[:url]))
            html2 = rslt2.body

            book,cover_url = parse_result_data(html2, search_isbn, true)
            if first_result.nil?
              first_result = [book, cover_url]
            end

            log.debug { "got book #{book}" }

            if search_isbn
              search_isbn_canon = Library.canonicalise_ean(search_isbn)
              rslt_isbn_canon = Library.canonicalise_ean(book.isbn)
              if search_isbn_canon == rslt_isbn_canon
                log.info { "book #{book} is a match"}
                return [book, cover_url]
              end
              log.debug {"not a match, checking next"}
            else
              # no constraint to match isbn, just return first result
              return [book, cover_url]
            end
          end
          
          # gone through all and no ISBN match, so just return first result
          log.info {"no more results to check. Returning first result, just an approximation"}
          return first_result

        end

        title_header = doc%'h1.title'
        title = title_header.inner_text if title_header
        unless title
          log.warn { "Unexpected lack of title from WorldCat lookup" }
          raise NoResultsError
        end
        log.info { "Found book #{title} at WorldCat" }

        authors = []
        authors_tr = doc%'tr#details-allauthors'
        if authors_tr
          (authors_tr/:a).each do |a|
            authors << a.inner_text
          end
        end

        # can we do better? get the City name?? or multiple publishers?
        bibdata = doc % 'div#bibdata'
        bibdata_table = bibdata % :table
        publisher_row = bibdata_table % 'th[text()*=Publisher]/..'

        if publisher_row
          publication_info = (publisher_row/'td').last.inner_text

          if publication_info.index(';')
            publication_info =~ /;[\s]*([^\d]+)[\s]*[\d]*/
          elsif publication_info.index(':')
            publication_info =~ /:[\s]*([^;:,]+)/
          else
            publication_info =~ /([^;,]+)/
          end

          publisher = $1
          publication_info =~ /([12][0-9]{3})/
          year = $1.to_i if $1
        else
          publisher = nil
          year = nil
        end

        isbn = search_isbn
        unless isbn
          isbn_row = doc % 'tr#details-standardno' ##bibdata_table % 'th[text()*=ISBN]/..'
          if isbn_row
            isbns = (isbn_row/'td').last.inner_text.split
            isbn = Library.canonicalise_isbn(isbns.first)
          else
            log.warn { "No ISBN found on page" }            
          end
        end

        binding = "" # not given on WorldCat website (as far as I can tell)

        book = Book.new(title, authors, isbn, publisher, year, binding)

        image_url = nil # hm, it's on the website, but uses JavaScript...

        return [book, image_url]
        
      rescue Exception => ex
        raise ex if ex.instance_of? NoResultsError
        trace = ex.backtrace.join("\n> ")
        log.warn {"Failed parsing search results for WorldCat " +
          "#{ex.message} #{trace}" }
        raise NoResultsError
      end
      
    end


    end # class WorldCatProvider
  end # class BookProviders
end # module Alexandria
  
