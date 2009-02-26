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

# AdLibris  Bokhandel AB http://www.adlibris.com/se/ 
# Swedish online book store

# New AdLibris provider, taken from the Palatina MetaDataSource and
# modified to fit the structure of Alexandria book providers.
# (26 Feb 2009)

require 'cgi'
require 'alexandria/net'
require 'iconv' # part of ruby-gettext


module Alexandria
  class BookProviders
    class AdLibrisProvider < GenericProvider
      include Alexandria::Logging

      SITE = "http://www.adlibris.com/se/"
      
      BASE_SEARCH_URL = "#{SITE}searchresult.aspx?search=advanced&%s=%s" +
        "&fromproduct=False" # type/term
      
      PRODUCT_URL = "#{SITE}product.aspx?isbn=%s"

      def initialize()
        super("AdLibris", "AdLibris (Sweden)")
        @ent = HTMLEntities.new
      end

      ## search (copied from new WorldCat search)
      def search(criterion, type)
        #puts create_search_uri(type, criterion)
        req = create_search_uri(type, criterion)
        html_data = transport.get_response(URI.parse(req))

        #puts html_data.class
        if type == SEARCH_BY_ISBN
          parse_result_data(html_data.body)
        else
          results = parse_search_result_data(html_data.body)
          raise NoResultsError if results.empty?

          results.map {|result| get_book_from_search_result(result) }          
        end

      end



      ## url
      def url(book)
        create_search_uri(SEARCH_BY_ISBN, book.isbn)
      end

      private 

      def create_search_uri(search_type, search_term)
        if search_type == SEARCH_BY_ISBN
          PRODUCT_URL % Library.canonicalise_isbn(search_term)
        else
          search_type_code = {SEARCH_BY_AUTHORS => 'author',
            SEARCH_BY_TITLE => 'title',
            SEARCH_BY_KEYWORD => 'keyword'
          }[search_type] or 'keyword'
          search_term_encoded = CGI.escape(search_term)
          BASE_SEARCH_URL % [search_type_code, search_term_encoded]
        end
      end

      # TODO use Iconv to pre-convert the html.body to UTF-8 everywhere
      # before sending it to the parser methods

      def parse_search_result_data(html)
        # adlibris site presents data in ISO-8859-1, so change it to UTF-8
        html = Iconv.conv("UTF-8", "ISO-8859-1", html)
        doc = Hpricot(html)
        book_search_results = []

        searchHit = doc%'table[@id$="SearchHit"]'
        return [] unless searchHit

        (searchHit/'table[@id$="Table1"]').each do |t|

          result = {}
          if title_row = (t%'tr[@id$="trTitle"]')
            td = title_row%:td
            result[:title] = (td%:a).inner_text
            #binding = (td%'span[@id$=Label4]').inner_text # " (...)"
            #author = (td%'span[@id$=Label2]').inner_text # " surname, forename"
          end
          #authors = [author]

          #isbn_text = (t%'span[@id$=Label5]').inner_text
          #isbn_text =~ /([0-9]{13}|[0-9]{10}|[0-9]{9}X)/i
          #isbn = $1

          #book = Book.new(title, ISBN.get(isbn), authors)
          # book.binding

          if link = t%'a[@id$="linkProduct"]'
            result[:lookup_url] = "#{SITE}#{link['href']}"
            #if img = (link%'img[@id$="ProductImageLinked"]')
            #  cover_url = "#{SITE}#{img['src']}"#
            #end
          end




          book_search_results << result

        end
        book_search_results
      end
      

      #def binding_type(binding) # swedish string
      #  # hrm, this is a HACK and not currently working
      #  # perhaps use regexes instead...
      #  {"inbunden" => :hardback,
      #    "pocket" => :paperback,
      #    "storpocket" => :paperback,
      #    "kartonnage" => :hardback,
      #    "kassettbok" => :audiobook}[binding.downcase] or :paperback      
      #  # H&#228;ftad == Paperback
      #end

      def normalize(text)
        unless text.nil?
          text = @ent.decode(text)
        end
        text
      end

      def parse_result_data(html)
        # adlibris site presents data in ISO-8859-1, so change it to UTF-8
        html = Iconv.conv("UTF-8", "ISO-8859-1", html)
        File.open(',log.html', 'wb') {|f| f.write('<?xml encoding="utf-8"?>'); f.write(html) } # DEBUG
        doc = Hpricot(html)     
        product_table = doc%'table[@id$="ProductTable"]'
        raise NoResultsError unless product_table
        begin
          
          title = nil
          if h1 = product_table%:h1
            title = normalize(h1.inner_text)
          end



          author_cells = product_table/'td/h2/a[@id*="Author"]/../..'
          authors = []
          author_cells.each do |td|
            author_role = (td%:span).inner_text # first span contains author_role
            author_name = (td%:a).inner_text # link contains author_name
            authors << normalize(author_name)
          end

          publisher = nil
          if publisher_elem = product_table%'span[@id$="PublisherName"]'
            publisher = normalize(publisher_elem.inner_text)
          end

          binding = nil
          if format_elem = product_table%'span[@id$="FormatAndLanguage"]'
            binding = format_elem.inner_text
            if binding =~ /:[\s]*([^,]+),/
              binding = normalize($1)
            end
          end

          year = nil
          if publication_elem = product_table%'span[@id$="PublishedAndPages"]'
            publication = publication_elem.inner_text
            if publication =~ /([12][0-9]{3})/
              year = $1.to_i
            end
          end
          
          isbns = []
          isbn_elems = product_table/'span[@id$="Isbn"]' # or Isbn13
          isbn_elems.each do |isbn_elem|
            isbn = isbn_elem.inner_text
            if isbn =~ /:[\s]*([0-9x]+)/i
              isbn = $1
            end
            isbns << isbn
          end
          isbn =  isbns.first
          if isbn
            isbn = Library.canonicalise_isbn(isbn)
          end

          #cover
          image_url = nil
          if cover_img = product_table%'img[@id$="ProductImageNotLinked"'
            image_url = cover_img['src'] # already absolute
            if image_url =~ /noimage.gif$/
              # no point downloading a "no image" graphic
              # Alexandria has its own generic book icon...
              image_url = nil
            end
            #puts image_url
          end
          
          #book = Book.new(title, ISBN.get(isbns.first), authors)
          
          #if publisher
          #  book.publisher = Publisher.new(publisher)
          #end
          #if binding
          #  book.binding = CoverBinding.new(binding, binding_type(binding))
          #end
          
          #if year
          #  book.publication_year = year
          #end

          book = Book.new(title, authors, isbn, publisher, year, binding)

          return [book, image_url]
        rescue Exception => ex
          raise ex if ex.instance_of? NoResultsError
          trace = ex.backtrace.join("\n> ")
          log.warn {"Failed parsing search results for AdLibris " +
            "#{ex.message} #{trace}" }
          raise NoResultsError
        end
      end

    end
  end
end
