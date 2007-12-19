# Copyright (C) 2004 Laurent Sansonetti
# Copyright (C) 2007 Laurent Sansonetti and Marco Costantini
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

require 'net/http'
require 'cgi'

module Alexandria
  class BookProviders
    class SicilianoProvider < GenericProvider

      BASE_URI = "http://www.siciliano.com.br"
      LOCALE = "livro" # possible locales are: "livro", "importado"
      def initialize
        super("LS", "Livraria Siciliano (Brasil)")
        # no preferences for the moment
      end

      def search(criterion, type)
        criterion = criterion.convert("ISO-8859-1", "UTF-8")
        req = BASE_URI + "/#{LOCALE}.asp?tipo=10&pesquisa="
        req += case type
               when SEARCH_BY_ISBN
                 "5&id="

               when SEARCH_BY_TITLE
                 "1&id="

               when SEARCH_BY_AUTHORS
                 "3&id="

               when SEARCH_BY_KEYWORD
                 "&id=" # does the site provide this?

               else
                 raise InvalidSearchTypeError

               end

        criterion = Library.canonicalise_isbn(criterion) if type == SEARCH_BY_ISBN
        req += CGI.escape(criterion)
        p req if $DEBUG
        data = transport.get(URI.parse(req))

        if type == SEARCH_BY_ISBN
          book = to_book(data)
        else
          begin
            results = []
            each_book_page(data) do |code, title|
              results << to_book(transport.get(URI.parse(BASE_URI + "/#{LOCALE}.asp?orn=LSE&Tipo=2&ID=" + code)))
            end
            return results
          rescue
            raise NoResultsError
          end
        end
      end

      def url(book)
        "http://www.siciliano.com.br/#{LOCALE}.asp?tipo=10&pesquisa=5&id=" +  Library.canonicalise_isbn(book.isbn)
      end

      #######
      private
      #######

      def to_book(data)
        data = data.convert("UTF-8", "ISO-8859-1")
        raise NoResultsError if /<strong>Nenhum t.tulo foi encontrado\.<BR>/.match(data) != nil

        raise "No Title" unless md = /><strong(\s+class="titulodetalhes")?>([^<]+)<\/strong>(<\/a>)?<br ?\/>/.match(data)
        title = md[2].strip

        authors = []
        if md =/<strong class="(azulescuro|autordetalhes)">(.*)<\/strong><br ?\/><br ?\/>/.match(data)
          md[2].strip.split(', ').each { |a| authors << CGI.unescape(a.strip) }
        end

        raise "No ISBN from Image" unless md = /<img src="capas\/([\dX]+)p?\.jpg" alt="" ?\/>/.match(data)
        isbn = Library.canonicalise_ean(md[1].strip)

        if md = /<br[^>]*>Editora: ([^<]+)<br>/.match(data)
          publisher = md[1].strip
        else
          publisher = nil
        end

        if md = /<br[^>]*>Encaderna..o: ([^<]+)<br>/.match(data)
          edition = md[1].strip
        else
          edition = nil
        end

        if md = /<br[^>]*>Edi..o: ([^<]+)<br>/.match(data)
          publish_year = md[1].strip.to_i
        else
          publish_year = nil
        end

        medium_cover = BASE_URI+'/capas/'+ Library.canonicalise_isbn(isbn) + 'p.jpg' # use + '.jpg' for bigger images
        #raise "No Big Image" unless medium_cover = transport.get(URI.parse(BASE_URI+'/capas/'+ isbn + '.jpg'))
        #raise "No Big Image" unless md = /<img src="capas\/(.+\/(\d+)p\.gif)" alt=""\/>/.match(data)
        #medium_cover = md[1]
        #small_cover = md[1]
        return [ Book.new(title, authors, isbn, publisher, publish_year, edition),
                 medium_cover ]
      end

      def each_book_page(data)
        raise if data.scan(/<a href='#{LOCALE}.asp\?orn=LSE&Tipo=2&ID=(\d+)'><strong>/) { |a| yield a }.empty?
      end
    end
  end
end
