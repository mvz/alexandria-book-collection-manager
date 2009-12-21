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

# New DeaStore provider, taken from the Palatina MetaDataSource and
# modified to fit the structure of Alexandria book providers.
# (24 Feb 2009)

require 'cgi'
require 'alexandria/net'

module Alexandria
  class BookProviders
    class DeaStoreProvider < WebsiteBasedProvider
      include Alexandria::Logging

      SITE = "http://www.deastore.com"
      BASE_SEARCH_URL = "#{SITE}/search/italian_books/0/%s/%s" # type/term
    
      def initialize()
        super("DeaStore", "DeaStore (Italy)")
        prefs.read
        @agent = nil
      end

      def agent      
        unless @agent
          @agent = Alexandria::WWWAgent.new
          @agent.language = :it
        end        
        @agent
      end


      def get_book_from_search_result(result)
        log.debug { "Fetching book from #{result[:url]}" }
        html_data = agent.get(result[:url])
        #File.open("rsltflarn#{Time.now().usec()}.html", 'wb') do |f|
        #  f.write(html_data.body)
        #end
        parse_result_data(html_data.body)
      end

      def search(criterion, type)
        begin
          criterion = criterion.convert("ISO-8859-1", "UTF-8") # still needed??
        rescue GLib::ConvertError
          log.info { "Cannot search for non-ISO-8859-1 terms at DeaStore : #{criterion}" }
          raise NoResultsError
        end
        html_data = agent.get(create_search_uri(type, criterion))
        #File.open("flarn#{Time.now().usec()}.html", 'wb') do |f|
        #  f.write(html_data.body)
        #end
        results = parse_search_result_data(html_data.body)
        raise NoResultsError if results.empty?

        if type == SEARCH_BY_ISBN
          get_book_from_search_result(results.first)
        else
          results.map {|result| get_book_from_search_result(result) }
        end

      end

      # it isn't possible to create a URL for a book given only the ISBN...
      def url(book)
        nil
      end

      private

      
      def create_search_uri(search_type, search_term)        
        # bah! very, very similar to the siciliano code! refactor out this duplication
        search_type_code = {SEARCH_BY_ISBN => 'isbn',
          SEARCH_BY_TITLE => 'title',
          SEARCH_BY_AUTHORS => 'author',
          SEARCH_BY_KEYWORD => 'keywords'
        }[search_type] or 'keywords'

        search_term_encoded = search_term
        if search_type == SEARCH_BY_ISBN
          search_term_encoded = Library.canonicalise_isbn(search_term) # isbn-10
        else
          search_term_encoded = CGI.escape(search_term)
        end

        uri = BASE_SEARCH_URL % [search_type_code, search_term_encoded]
        log.debug { uri }
        uri
      end

      def parse_search_result_data(html)
        doc = html_to_doc(html)
        book_search_results = []
        
        result_divs = doc.search('div.scheda_prodotto')
        result_divs.each do |div|
          begin
            # The layout...
            # a > img
            # div.scheda_content
            #  a[link->productpage] title ##  a.titolo_link
            #  p (genre I think) ##  !ignore
            #  a[link->author] author ## a.info
            #  p.editore (publisher? editor?)
            #  p Data di pubblicazione: \n     2009
            #  p.prezzo (price)
            
#             cover_url = ''
#             cover_images = div/'a/img'
#             unless cover_images.empty?
#               img = cover_images.first
#               image_url = img['src']
#               if image_url =~ /^http/
#                 cover_url = '' # image_url
#               elsif image_url[0..0] != '/'
#                 cover_url = "#{SITE}/#{image_url}"
#               else
#                 cover_url = "#{SITE}#{image_url}"
#               end
#               log.debug { "Search Cover Image URL #{cover_url}" }

#             end
            
            content = div/'div.scheda_content'
            title_link = (content/:a).first
            title = normalize(title_link.inner_text)
            link_to_description = title_link['href']
            lookup_url =  "#{SITE}#{link_to_description}"
            
            authors = []
            (content/'a.info').each do |link|
              authors << normalize(link.inner_text)
            end
            

            result = {}
            result[:author] = authors.first # HACK, what about multiple authors
            result[:title] = title
            result[:url] = lookup_url
            
            publishers = (content/'p.editore')
            unless publishers.empty?
              result[:publisher] = normalize(publishers.first.inner_text)
            end

            book_search_results << result
          rescue Exception => ex
            trace = ex.backtrace.join("\n> ")
            log.error { "Failed parsing DeaStore search page #{ex.message}\n#{trace}" }
          end
        end
        book_search_results
      end
        
      
      def parse_result_data(html)
        begin
          doc = html_to_doc(html)
          data = doc%'div#dati_scheda'

          sotto_data_hdr = doc%'div.sotto_schede/h1.titolo_sotto[text()*="Informazioni generali"]/..'
          
          # title
          title_span = data%'h1.titolo_scheda'
          title = normalize(title_span.inner_text)

          # cover
          cover_link = nil
          cover_img = data/'a/img'
          unless cover_img.empty?
            cover_link = cover_img.first['src']
          end
          
          # author(s)
          authors = []
          author_span = data%'span.int_scheda[text()*=Autore]'
          unless author_span
            author_span = data%'span.int_scheda[text()*=cura]' # editor
          end
          if author_span
            author_links = author_span/'a.info'
            authors = []
            author_links.each do |link|
              authors << normalize(link.inner_html)
            end
          end

          #if author_span
          #  author_links = author_span/'a.info'
          #  author_links.each do |link|
          #    authors << normalize(link.inner_text)
          #  end
          #end

          # publisher
          publisher_par = data%'span.int_scheda[text()*=Editore]/..'
          publisher_link = publisher_par%'a.info'
          publisher = normalize(publisher_link.inner_text)

          # skip 'Collana', (ummm, possibly genre information, Babelfish
          # says "Necklace")
          
          # format
          format_par = data%'span.int_scheda[text()*=Formato]/..'
          format_par.inner_text =~ /:[\s]*(.+)[\s]*$/
          binding = normalize($1)

          # year
          date_par = data%'span.int_scheda[text()*=Data di pubblicazione]/..'
          date_par.inner_text =~ /:[\s]*([12][0-9]{3})[\s]*$/
          publish_year = nil
          if $1
            publish_year = $1.to_i
          end

          isbn_spans = data/'div.sotto/span.isbn'
          isbns = []
          isbn_spans.each do |span|
            span.inner_text =~ /:[\s]*(.+)[\s]*$/
            isbns << $1
          end

          isbn = nil
          unless isbns.empty?          
            isbn = Library.canonicalise_isbn(isbns.first)
          end

          # Editore & Imprint : as publisher info above...

          # pages
          #page_par = data%'span.int_scheda[text()*=Pagine]/..'
          #if page_par
          #  page_par.inner_text =~ /:[\s]*([0-9]+)[\s]*$/
          #  pages = $1.to_i
          #end

          #synopsis_div = doc%'div.sotto_schede' # exclude the first span though

          
          #book = Book.new(title, isbns.first, authors)
          #if publisher
          #  book.publisher = Publisher.new(publisher)
          #end
          #if format
          #  book.binding = CoverBinding.new(format, binding_type(format))
          #end
          

          #cover
          image_url = nil
          if cover_link
            if cover_link =~ /^http/
              # e.g. http://images.btol.com/ContentCafe/Jacket.aspx?\
              # Return=1&amp;Type=M&amp;Value=9788873641803&amp;password=\
              # CC70580&amp;userID=DEA40305
              # seems not to work, or to be blank anyway, so set to nil
              image_url = nil
            elsif cover_link[0..0] != '/'
              image_url = "#{SITE}/#{cover_link}"
            else
              image_url = "#{SITE}#{cover_link}"
            end

            log.debug { "Cover Image URL:: #{image_url}" }
          end

          book = Book.new(title, authors, isbn, publisher, publish_year, binding)

          return [book, image_url]
        rescue Exception => ex
          trace = ex.backtrace.join("\n> ")
          log.error { "Failed parsing DeaStore product page #{ex.message}\n#{trace}" }
          return nil        
        end
      end


      def normalize(str)
        unless str.nil?
          str = str.squeeze(' ').strip()
        end
        str
      end
      
      
      
    end
  end
end
