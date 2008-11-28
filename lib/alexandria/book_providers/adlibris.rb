# Copyright (C) 2005 Rene Samselnig - Modified by Linus Zetterlund
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

## Modified by Cathal Mc Ginley 2008-01-13
##   added check for instances where cover image not available
##   fixes #16853

### Modified by Simon Edwardsson 2008-09-01
###  Updating the url

#### Modified by Martin Karlsson 2008-11-27
#### Updated some regular expressions

# TODO:
# fix едц


require 'net/http'
require 'cgi'


module Alexandria
  class BookProviders
    class AdlibrisProvider < GenericProvider
      BASE_URI = "http://www.adlibris.com/se/"
      def initialize
        super("Adlibris", "Adlibris (Sweden)")
        # no preferences for the moment
      end

      def search(criterion, type)
	#criterion = criterion.convert("windows-1252", "UTF-8")
    	criterion = criterion.convert("ISO-8859-1", "UTF-8")
        req = BASE_URI
        if type == SEARCH_BY_ISBN
          req += "product.aspx?isbn="+criterion+"&checked=1"
        elsif type == SEARCH_BY_KEYWORD
          search_criterions = {}
          search_criterions[type] = CGI.escape(criterion)
	  req = "http://www.adlibris.com/se/searchresult.aspx?search=quickfirstpage&quickvalue="+search_criterions[SEARCH_BY_KEYWORD].to_s()+"&title="+search_criterions[SEARCH_BY_KEYWORD].to_s()+"&fromproduct=False"
	else
          search_criterions = {}
          search_criterions[type] = CGI.escape(criterion)
	  req = "http://www.adlibris.com/se/searchresult.aspx?search=advanced&title="+search_criterions[SEARCH_BY_TITLE].to_s()+"&author="+search_criterions[SEARCH_BY_AUTHORS].to_s()+"&fromproduct=False"
        end
	
        results = []

        if type == SEARCH_BY_ISBN
          #puts "if type == SEARCH_BY_ISBN"
	  data = transport.get(URI.parse(req))
	  return to_book_isbn(data, criterion) #rescue raise NoResultsError
        else
          begin
            data = transport.get(URI.parse(req+"&row=1"))

            regx = /<a id="ctl00_main_frame_ctrlsearchhit_rptSearchHit_ctl0\d+_hlkTitle" href="product\.aspx\?isbn=(\d{10,13})/

            begin
              data.scan(regx) do |md| next unless md[0] != md[1]
                isbn = md[0]
		req = BASE_URI + "product.aspx?isbn="+isbn
		bookdata = transport.get(URI.parse(req))

                results << to_book_isbn(bookdata,isbn)
              end
            rescue => e
              puts e.message
            end

            return results
          rescue
            raise NoResultsError
          end
        end
      end

      def url(book)
        #puts "debug: url(book)"
        BASE_URI + "product.aspx?isbn=" + book.isbn
      end

      #######
      private
      #######

      def translate_html_stuff!(r)
        r.sub!('&#229;','ГҐ') # е
        r.sub!('&#228;','Г¤') # д
        r.sub!('&#246;','Г¶') # ц
        r.sub!('&#197;','Г.') # Е
        r.sub!('&#196;','Г.') # Д
        r.sub!('&#214;','Г.') # Ц
        return r
      end
      def translate_html_stuff(s)
        r = s
        translate_html_stuff!(r)
        return r
      end


      def translate_stuff_stuff!(r)
        #r.sub!('\е','ГҐ') # е
        #r.sub!('\д','Г¤') # д
        #r.sub!('\ц','Г¶') # ц
        #r.sub!('\Е','Г.') # Е
        #r.sub!('\Д','Г.') # Д
        #r.sub!('\Ц','Г.') # Ц
        return r
      end
      def translate_stuff_stuff(s)
        r = s
        translate_stuff_stuff!(r)
        return r
      end


      def to_book_isbn(data, isbn)
	raise NoResultsError if /Ingen titel med detta ISBN finns hos AdLibris/.match(data) != nil
        data = data.convert("UTF-8", "ISO-8859-1")

        product = {}


        raise "Title not found" unless md = /<span id="ctl00_main_frame_ctrlproduct_lblProductTitle" class="header15">(.+)<\/span>/.match(data)

        product["title"] = CGI.unescape(md[1])


        #                       regx = /<tr><td colspan="2" class="text">F&#246;rfattare:&nbsp;<b>([^<]*)<\/b><\/td><\/tr>/
        regx = /<span id="ctl00_main_frame_ctrlproduct_rptAuthor_ctl0\d+_Label2">.+<\/span>:&nbsp;<a [^>]+>([^<]+)<\/a>/
        product["authors"] = []
        data.scan(regx) do |md| next unless md[0] != md[1]
          product["authors"] << translate_html_stuff(CGI.unescape(md[0]))
        end

        #raise "Publisher string not found, but no \"book not found\" string found\n" unless
        md = /<span id="ctl00_main_frame_ctrlproduct_lblPublisherName">(.+)<\/span>/.match(data)

        product["publisher"] = md[1] or md #i.e., or nil


        #raise "No edition" unless
        md = /<span id="ctl00_main_frame_ctrlproduct_lblFormatAndLanguage">Bandtyp: ([^,]*).+<\/span>/.match(data)

        product["edition"] = md[1] or md


        md = /Utgiven: (\d\d\d\d)/.match(data)
        # FIXME
        #                publish_year = either CGI.unescape(md[1].strip).to_i or md[1].to_i
        #                publish_year = nil if publish_year == 0

        product["publish_year"] = md[1] or md


        isbn10 = Library.canonicalise_isbn(isbn)

        img_url = "covers/" + isbn10[0 .. 0] + "/" + isbn10[1 .. 2] + "/" + isbn10 + ".jpg"
        if data.match(img_url)
          product["cover"] = BASE_URI + img_url
        else
          product["cover"] = nil
        end


        book = Book.new(
                        translate_html_stuff(product["title"]),
                        product["authors"],
                        Library.canonicalise_ean(isbn),
                        translate_html_stuff(product["publisher"]),
                        product["publish_year"],
                        translate_html_stuff(product["edition"]))
        return [ book, product["cover"] ]
      end

    end
  end
end
