# Copyright (C) 2007 Marco Costantini
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
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

require 'fileutils'
require 'net/http'
require 'open-uri'
#require 'cgi'

module Alexandria
class BookProviders
    class Webster_itProvider < GenericProvider
        BASE_URI = "http://www.libreriauniversitaria.it" # also "http://www.webster.it"
        CACHE_DIR = File.join(Alexandria::Library::DIR, '.webster_it_cache')
        REFERER = BASE_URI
        def initialize
            super("Webster_it", "Webster Italia")
            FileUtils.mkdir_p(CACHE_DIR) unless File.exists?(CACHE_DIR)            
            # no preferences for the moment
            at_exit { clean_cache }
        end
        
        def search(criterion, type)
            req = BASE_URI + "/"
            req += case type
                when SEARCH_BY_ISBN
                    "BIT/"

                when SEARCH_BY_TITLE
                    "c_search.php?noinput=1&shelf=BIT&title_query="

                when SEARCH_BY_AUTHORS
                    "c_search.php?noinput=1&shelf=BIT&author_query="

                when SEARCH_BY_KEYWORD
                    "c_search.php?noinput=1&shelf=BIT&subject_query="

                else
                    raise InvalidSearchTypeError

            end
            
if type == SEARCH_BY_ISBN
            req += Library.canonicalise_isbn(criterion)
else
            req += CGI.escape(criterion)
end
            p req if $DEBUG
	        data = transport.get(URI.parse(req))
            if type == SEARCH_BY_ISBN
                to_book(data) rescue raise NoResultsError
            else
                begin
                    results = [] 
                    each_book_page(data) do |code, title|
                        results << to_book(transport.get(URI.parse(BASE_URI + "/BIT/" + code)))
                    end
                    return results 
                rescue
                    raise NoResultsError
                end
            end
        end

        def url(book)
            return nil unless book.isbn
            BASE_URI + "/BIT/" + Library.canonicalise_isbn(book.isbn)
        end

        #######
        private
        #######
    
        def to_book(data)
            raise unless md = /<li><span class="product_label">Titolo:<\/span><span class="product_text"> ([^<]+)/.match(data)
            title = CGI.unescape(md[1].strip)
            if md = /<span class="product_heading_volume">([^<]+)/.match(data)
                title += " " + CGI.unescape(md[1].strip)
            end
            authors = []
	    
	  if   md = /<li><span class="product_label">Autor([ei]):<\/span> <span class="product_text"><a href="([^>]+)>([^<]+)/.match(data)
                 authors = [CGI.unescape(md[3].strip)]
#            md[1].split(', ').each { |a| authors << CGI.unescape(a.strip) }
          end

            raise unless md = /<li><span class="product_label">ISBN:<\/span> <span class="product_text">([^<]+)/.match(data)
            isbn = "978" + md[1].strip[0..8]
            isbn += String( Library.ean_checksum( Library.extract_numbers( isbn ) ) )

            raise unless md = /<li><span class="product_label">Editore:<\/span> <span class="product_text"><a href="([^>]+)>([^<]+)/.match(data)
	        publisher = CGI.unescape(md[2].strip)

           if md = /<li><span class="product_label">Pagine:<\/span> <span class="product_text">([^<]+)/.match(data)
             edition = "p. " + CGI.unescape(md[1].strip)
           else
             edition = nil
           end

            publish_year = nil
            if md = /<li><span class="product_label">Data di Pubblicazione:<\/span> <span class="product_text">([^"]+)/.match(data)
                publish_year = CGI.unescape(md[1].strip).to_i
                publish_year = nil if publish_year == 0
            end

  if data =~ /javascript:popImage/

            cover_url = BASE_URI + "/data/images/BIT/" + isbn[9 .. 11] + "/" + isbn + "p.jpg" # use "g" instead of "p" for bigger image
            cover_filename = isbn + ".tmp"
            Dir.chdir(CACHE_DIR) do
                File.open(cover_filename, "w") do |file|
                    file.write open(cover_url, "Referer" => REFERER ).read
                end                    
            end

            medium_cover = CACHE_DIR + "/" + cover_filename
            if File.size(medium_cover) > 0
                puts medium_cover + " has non-0 size" if $DEBUG
                return [ Book.new(title, authors, isbn, publisher, publish_year, edition),medium_cover ]
            end
            puts medium_cover + " has 0 size, removing ..." if $DEBUG
            File.delete(medium_cover)
  end
            return [ Book.new(title, authors, isbn, publisher, publish_year, edition) ]
        end

        def each_book_page(data)
	        raise if data.scan(/<tr ><td width="10%" align="center"">&nbsp;<a href="BIT\/([^\/]+)/) { |a| yield a}.empty?
        end
    
        def clean_cache
            #FIXME begin ... rescue ... end?
            Dir.chdir(CACHE_DIR) do
                Dir.glob("*.tmp") do |file|
                    puts "removing " + file if $DEBUG
                    File.delete(file)    
                end
            end
        end
    end
end
end

