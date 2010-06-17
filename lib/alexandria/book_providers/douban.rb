# -*- ruby -*-
#
# Copyright (C) 2009 Cathal Mc Ginley
# Copyright (C) 2010 Sun Ning
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

# http://book.douban.com/
# Douban.com book repository, provides many Chinese books.

# Author: Sun Ning <classicning@gmail.com>, http://sunng.info/


require 'cgi'
require 'alexandria/net'
require 'yaml'

module Alexandria
  class BookProviders
    class DoubanProvider < GenericProvider
      include Alexandria::Logging
	
      SITE = "http://www.douban.com"
      BASE_URL = "http://api.douban.com/book/subjects?q=%s&max-results=5&alt=json"

      def initialize()
        super("Douban", "Douban (China)")
        prefs.read
      end

      def url(book)
        nil
      end

      
      def search(criterion, type)
        keyword = criterion
        request_url = BASE_URL % CGI.escape(keyword)
        
        search_response = transport.get_response(URI.parse(request_url))

        results = parse_search_result(search_response.body)
        if results.length == 0
          raise NoResultsError
        end
        
        if type == SEARCH_BY_ISBN
          return results.first
        else
          return results
        end
      end
      
      private

      # The YAML parser in Ruby 1.8.6 chokes on the extremely
      # compressed inline-style of JSON returned by Douban. (Also, it
      # doesn't un-escape forward slashes). 
      #
      # This is a quick-and-dirty method to pre-process the JSON into
      # YAML-parseable format, so that we don't have to drag in a new
      # dependency.
      def json2yaml(json)
        # insert spaces after : and , except within strings
        # i.e. when followed by numeral, quote, { or [
        yaml = json.gsub(/(\:|\,)([0-9'"{\[])/) do |match|
          "#{$1} #{$2}"
        end        
        yaml.gsub!(/\\\//, '/') # unescape forward slashes
        yaml
      end

      public 
      

      def parse_search_result(response)
        book_search_results = []
        begin
          #dbresult = JSON.parse(response)          
          dbresult = YAML::load(json2yaml(response))
          #File.open(",douban.yaml", "wb") {|f| f.write(json2yaml(response)) }
          if(dbresult['opensearch:totalResults']['$t'].to_i > 0)
            for item in dbresult['entry']
              name = item['title']['$t']
              isbn = nil
              publisher = nil
              pubdate = nil
              binding = nil
              for av in item['db:attribute']
                  if av['@name'] == 'isbn13'
                      isbn = av['$t']
                  end
                if av['@name'] == 'publisher'
                    publisher = av['$t']
                end
                if av['@name'] == 'pubdate'
                    pubdate = av['$t']
                end
                if av['@name'] == 'binding'
                    binding = av['$t']
                end
              end
              if item['author']
                authors = item['author'].map{ |a| a['name']['$t'] }
              else
                authors = []
              end
              image_url = nil
              for av in item['link']
                if av['@rel'] == 'image'
                  image_url = av['@href']
                end
              end
              book = Book.new(name, authors, isbn, publisher, pubdate, binding)
              book_search_results << [ book, image_url ]
            end
          end
        rescue Exception => ex
          log.warn(ex.backtrace.join('\n'))
        end
        book_search_results
      end
    end
  end
end


