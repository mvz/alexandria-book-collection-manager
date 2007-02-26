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
begin
    # rubygems may be required or not by hpricot (used by mechanize), and may be installed or not
    require 'rubygems'
rescue LoadError
end
require 'mechanize'
#require 'cgi'

module Alexandria
class BookProviders
    class DeaStore_itProvider < GenericProvider
        BASE_URI = "http://www.deastore.com"
        CACHE_DIR = File.join(Alexandria::Library::DIR, '.deastore_it_cache')
        def initialize
            super("DeaStore_it", "DeaStore (Italy)")
            FileUtils.mkdir_p(CACHE_DIR) unless File.exists?(CACHE_DIR)            
            # no preferences for the moment
            at_exit { clean_cache }
        end
        
        def search(criterion, type)
            criterion = criterion.convert("windows-1252", "utf-8")
            req = BASE_URI + "/"
            req += case type
                when SEARCH_BY_ISBN
                     "product.asp?isbn="

                when SEARCH_BY_TITLE
                    "ricerche.asp?quick_search=ok&order_by=relevance&query_field=allbooks&query_string="

                when SEARCH_BY_AUTHORS
                    "ricerche.asp?quick_search=ok&order_by=relevance&query_field=allbooks&query_string="

                when SEARCH_BY_KEYWORD
                    "ricerche.asp?quick_search=ok&order_by=relevance&query_field=allbooks&query_string="

                else
                    raise InvalidSearchTypeError

            end

            req += CGI.escape(criterion)
            p req if $DEBUG

            agent = WWW::Mechanize.new
            agent.user_agent_alias = 'Mac Safari'
            #data = transport.get(URI.parse(req))
            data = agent.get(URI.parse(req)).content

            if type == SEARCH_BY_ISBN
                to_book(data) #rescue raise NoResultsError
            else
                begin
                    results = [] 
                    each_book_page(data) do |code, title|
                        agent = WWW::Mechanize.new
                        agent.user_agent_alias = 'Mac Safari'
                        results << to_book(agent.get(URI.parse(BASE_URI + "/" + code)).content)
                    end
                    return results 
                rescue
                    raise NoResultsError
                end
            end
        end

        def url(book)
            BASE_URI + "/product.asp?isbn=" + book.isbn
        end

        #######
        private
        #######
    
        def to_book(data)
            data = data.convert("UTF-8", "windows-1252")

            raise "No title." unless md = /<span class="BDtitoloLibro">([^<]+)/.match(data)
            title = CGI.unescape(md[1].strip)

            authors = []
	    if md = /<span class="BDauthLibro">by:([^<]+)/.match(data)
                md[1].strip.split('- ').each { |a| authors << CGI.unescape(a.strip) }
            end

            raise "No ISBN" unless md = /<span class="BDEticLibro">ISBN 13: <\/span><span class="isbn">([^<]+)/.match(data)
            isbn = md[1].strip.gsub!("-","")

            #raise "No Publisher" unless 
            md = /<span class="BDeditoreLibro">([^<]+)/.match(data)
	        publisher = CGI.unescape(md[1].strip) or md

            unless md = /<span class="BDEticLibro">More info<\/span><br \/>([^<]+)/.match(data)
            	edition = nil
            else
            	edition = CGI.unescape(md[1].strip)
            end

            publish_year = nil
            if md = /<span class="BDdataPubbLibro">([^<]+)/.match(data)
                publish_year = CGI.unescape(md[1].strip)[-4 .. -1].to_i
                publish_year = nil if publish_year == 0 or publish_year == 1900
            end

  if md = /<div class="imageLg"><a href="javascript:void\(''\);" onclick="popUpCover\('\/covers_13\/([0-9\/]+)batch/.match(data)
            cover_url = BASE_URI + "/covers_13/" + md[1].strip + "/batch1/" + isbn + ".jpg" # use batch2 or batch3 for bigger images

            cover_filename = isbn + ".tmp"
            Dir.chdir(CACHE_DIR) do
                File.open(cover_filename, "w") do |file|
                    agent = WWW::Mechanize.new
                    agent.user_agent_alias = 'Mac Safari'
                    file.write agent.get(URI.parse(cover_url)).content
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
	        raise if data.scan(/<span class="BDtitoloLibro"><a href="([^"]+)/) { |a| yield a}.empty?
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
