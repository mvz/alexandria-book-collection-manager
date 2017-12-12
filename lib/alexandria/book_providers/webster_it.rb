# Copyright (C) 2007 Marco Costantini
# Copyright (C) 2014, 2016 Matijs van Zuijlen
# based on ibs_it.rb by Claudio Belotti
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

require 'fileutils'
require 'net/http'
require 'open-uri'
# require 'cgi'

module Alexandria
  class BookProviders
    class Webster_itProvider < GenericProvider
      BASE_URI = 'http://www.libreriauniversitaria.it'.freeze # also "http://www.webster.it"
      CACHE_DIR = File.join(Alexandria::Library::DIR, '.webster_it_cache')
      REFERER = BASE_URI
      # used only for search by title/author/keyword. possible are: "BIT", "BUS", "BUK", "BDE", "MIT"
      LOCALE = 'BIT'.freeze
      def initialize
        super('Webster_it', 'Webster (Italy)')
        FileUtils.mkdir_p(CACHE_DIR) unless File.exist?(CACHE_DIR)
        # no preferences for the moment
        at_exit { clean_cache }
      end

      def search(criterion, type)
        criterion = criterion.encode('ISO-8859-15')
        req = BASE_URI + '/'
        req += case type
               when SEARCH_BY_ISBN
                 'isbn/' # "#{LOCALE}/"

               when SEARCH_BY_TITLE
                 "c_search.php?noinput=1&shelf=#{LOCALE}&title_query="

               when SEARCH_BY_AUTHORS
                 "c_search.php?noinput=1&shelf=#{LOCALE}&author_query="

               when SEARCH_BY_KEYWORD
                 "c_search.php?noinput=1&shelf=#{LOCALE}&subject_query="

               else
                 raise InvalidSearchTypeError

               end

        req += CGI.escape(criterion)
        p req if $DEBUG
        data = transport.get(URI.parse(req))
        if type == SEARCH_BY_ISBN
          to_book(data) # rescue raise NoResultsError
        else
          begin
            results = []
            each_book_page(data) do |code, _title|
              results << to_book(transport.get(URI.parse(BASE_URI + "/#{LOCALE}/" + code)))
            end
            return results
          rescue
            raise NoResultsError
          end
        end
      end

      def url(book)
        BASE_URI + '/isbn/' + book.isbn
      end

      private

      AUTHOR_ITEM_REGEXP =
        %r{<li>
            <span\sclass="product_label">Autor[ei]:<\/span>
            \s<span\sclass="product_text">
            (<a\shref="[^>]+">([^<]+)<\/a>,? ?)+<\/span>
            <li>}x

      def to_book(data)
        raise NoResultsError if data =~ /<font color="\#ffffff"><b>Prodotto non esistente<\/b><\/font>/
        data = data.encode('UTF-8')

        md = /<li><span class="product_label">Titolo:<\/span><span class="product_text"> ([^<]+)/.match(data)
        raise unless md
        title = CGI.unescape(md[1].strip)
        if (md = /<span class="product_heading_volume">([^<]+)/.match(data))
          title += ' ' + CGI.unescape(md[1].strip)
        end

        authors = []
        if (md = AUTHOR_ITEM_REGEXP.match(data))
          this = CGI.unescape(md[0].strip)
          authors = this.scan(/<a href="[^>]+">([^<]+)<\/a>,?/)
          authors = authors.map { |author| author[0] }
        end

        md = /<li><span class="product_label">ISBN:<\/span> <span class="product_text">([^<]+)/.match(data)
        raise unless md
        isbn = Library.canonicalise_ean(md[1].strip)

        # raise unless
        md = /<li><span\ class="product_label">Editore:
              <\/span>\ <span\ class="product_text"><a href="[^>]+>([^<]+)/x.match(data)
        (publisher = CGI.unescape(md[1].strip)) || md

        md = /<li><span class="product_label">Pagine:<\/span> <span class="product_text">([^<]+)/.match(data)
        edition = (CGI.unescape(md[1].strip) + ' p.' if md)

        publish_year = nil
        md = /<li><span\ class="product_label">Data\ di\ Pubblicazione:
              <\/span>\ <span\ class="product_text">([^<]+)/x.match(data)
        if md
          publish_year = CGI.unescape(md[1].strip)[-4..-1].to_i
          publish_year = nil if publish_year.zero?
        end

        if data =~ /javascript:popImage/ && (md = /<img border="0" alt="[^"]+" src="([^"]+)/.match(data))
          cover_url = BASE_URI + md[1].strip
          # use "p" instead of "g" for smaller image
          cover_url[-5] = 112 if cover_url[-5] == 103

          cover_filename = isbn + '.tmp'
          Dir.chdir(CACHE_DIR) do
            begin
              cover_data = open(cover_url, 'Referer' => REFERER).read
            rescue OpenURI::HTTPError
              cover_data = nil
            end
            if cover_data
              File.open(cover_filename, 'w') do |file|
                file.write cover_data
              end
            end
          end

          medium_cover = CACHE_DIR + '/' + cover_filename
          if File.size(medium_cover) > 0
            puts medium_cover + ' has non-0 size' if $DEBUG
            return [Book.new(title, authors, isbn, publisher, publish_year, edition), medium_cover]
          end
          puts medium_cover + ' has 0 size, removing ...' if $DEBUG
          File.delete(medium_cover)
        end
        [Book.new(title, authors, isbn, publisher, publish_year, edition)]
      end

      def each_book_page(data, &blk)
        result = data.scan(/<tr ><td width="10%" align="center"">&nbsp;<a href="#{LOCALE}\/([^\/]+)/, &blk)
        raise if result.empty?
      end

      def clean_cache
        # FIXME: begin ... rescue ... end?
        Dir.chdir(CACHE_DIR) do
          Dir.glob('*.tmp') do |file|
            puts 'removing ' + file if $DEBUG
            File.delete(file)
          end
        end
      end
    end
  end
end
