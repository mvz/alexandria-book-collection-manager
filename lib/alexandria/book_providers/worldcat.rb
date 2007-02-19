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

# http://en.wikipedia.org/wiki/WorldCat
# See http://www.oclc.org/worldcat/policies/terms/

require 'fileutils'
require 'net/http'
require 'open-uri'
#require 'cgi'

module Alexandria
class BookProviders
    class WorldcatProvider < GenericProvider
        BASE_URI = "http://worldcat.org"
        CACHE_DIR = File.join(Alexandria::Library::DIR, '.worldcat_cache')
        REFERER = BASE_URI
        def initialize
            super("Worldcat", "Worldcat")
            FileUtils.mkdir_p(CACHE_DIR) unless File.exists?(CACHE_DIR)            
            # no preferences for the moment
            at_exit { clean_cache }
        end
        
        def search(criterion, type)
            req = BASE_URI + "/"
            req += case type
                when SEARCH_BY_ISBN
                    "isbn/"

                when SEARCH_BY_TITLE
                    "search?q=ti%3A"

                when SEARCH_BY_AUTHORS
                    "search?q=au%3A"

                when SEARCH_BY_KEYWORD
                    "search?q="

                else
                    raise InvalidSearchTypeError

            end
            
            # this provider supports both isbn-10 and isbn-13
            req += CGI.escape(criterion)
            p req if $DEBUG
	        data = transport.get(URI.parse(req))
            if type == SEARCH_BY_ISBN
                to_book(data) #rescue raise NoResultsError
            else
                begin
                    results = [] 
                    each_book_page(data) do |code, title|
                        results << to_book(transport.get(URI.parse(BASE_URI + "/oclc/" + code)))
                    end
                    return results 
                rescue
                    raise NoResultsError
                end
            end
        end

        def url(book)
            return nil unless book.isbn
            BASE_URI + "/isbn/" + book.isbn
        end

        #######
        private
        #######
    
        def to_book(data)

            raise unless md = /<h1 class="title"> (<div class=vernacular lang="[^"]+">)?([^<]+)/.match(data)
            title = CGI.unescape(md[2].strip)

	    	authors = []
	    	md = data.scan(/title="Search for more by this author">([^<]+)/)
            raise "No authors" unless md.length > 0
            md = md.collect {|match| match[0]} 
            md.each {|match|
            		CGI.unescape(match.strip)
            		authors << match		  
            		 }
#                 md[1].strip.split(', ').each { |a| authors << CGI.unescape(a.strip) }

            raise unless md = /<strong>ISBN: <\/strong>\w+\W+(\d+)\D/.match(data)
            isbn = md[1].strip

# The provider returns
# City : Publisher[ ; City2 : Publisher2], *year? [&copy;year]
# currently the match is not good in case of City2 : Publisher2 and in case of &copy;year

            if md = /<li class="publisher"><strong>Publisher: <\/strong>[^:<]+ : ([^<]+), [^,<]*(\d\d\d\d).?<\/li>/.match(data)
	        publisher = CGI.unescape(md[1].strip)
                publish_year = CGI.unescape(md[2].strip)[-4 .. -1].to_i
                publish_year = nil if publish_year == 0
            else
                publisher = nil
                publish_year = nil
             end

             edition = nil


  if md = /<td class="illustration"><img src="([^"]+)/.match(data)
            cover_url = BASE_URI + md[1].strip
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
            raise if data.scan(/<div class="name"><a href="\/oclc\/(\d+)&/) { |a| yield a}.empty?
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
