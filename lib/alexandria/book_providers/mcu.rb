# Copyright (C) 2004 Javier Fernandez-Sanguino
# Copyright (C) 2007 Javier Fernandez-Sanguino and Marco Costantini
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

require 'cgi'
require 'net/http'

# http://www.mcu.es/libro/CE/AgenciaISBN/BBDDLibros/Sobre.html
# http://www.mcu.es/comun/bases/isbn/ISBN.html

module Alexandria
  class BookProviders
    class MCUProvider < GenericProvider
      include Logging
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      LANGUAGES = {
        'es' => '1'
      }

      #        BASE_URI = "http://www.mcu.es/cgi-bin/BRSCGI3701?"
      BASE_URI = "http://www.mcu.es/cgi-brs/BasesHTML/isbn/BRSCGI?"
      def initialize
        super("MCU", _("Spanish Culture Ministry"))
        # No preferences
        prefs.read
      end

      def search(criterion, type)
        prefs.read
         begin
          criterion = criterion.convert("ISO-8859-1", "UTF-8") # still needed??
        rescue GLib::ConvertError
          log.info { "Cannot search for non-ISO-8859-1 terms at MCU : #{criterion}" }
          raise NoResultsError
        end
        print "Doing search with MCU #{criterion}, type: #{type}\n" if $DEBUG # for DEBUGing
        req = BASE_URI + "CMD=VERLST&BASE=ISBN&DOCS=1-15&CONF=AEISPA.cnf&OPDEF=AND&DOCS=1-1000&SEPARADOR=&"
        req += case type
               when SEARCH_BY_ISBN
                 "WGEN-C=&WISB-C=#{CGI::escape(criterion)}&WAUT-C=&WTIT-C=&WMAT-C=&WEDI-C=&WFEP-C=&%40T353-GE=&%40T353-LE=&WSER-C=&WLUG-C=&WDIS-C=%28DISPONIBLE+or+AGOTADO%29&WLEN-C=&WCLA-C=&WSOP-C="

               when SEARCH_BY_TITLE
                 "WGEN-C=&WISB-C=&WAUT-C=&WTIT-C=#{CGI::escape(criterion)}&WMAT-C=&WEDI-C=&WFEP-C=&%40T353-GE=&%40T353-LE=&WSER-C=&WLUG-C=&WDIS-C=%28DISPONIBLE+or+AGOTADO%29&WLEN-C=&WCLA-C=&WSOP-C="

               when SEARCH_BY_AUTHORS
                 "WGEN-C=&WISB-C=&WAUT-C=#{CGI::escape(criterion)}&WTIT-C=&WMAT-C=&WEDI-C=&WFEP-C=&%40T353-GE=&%40T353-LE=&WSER-C=&WLUG-C=&WDIS-C=%28DISPONIBLE+or+AGOTADO%29&WLEN-C=&WCLA-C=&WSOP-C="

               when SEARCH_BY_KEYWORD
                 "WGEN-C=#{CGI::escape(criterion)}&WISB-C=&WAUT-C=&WTIT-C=&WMAT-C=&WEDI-C=&WFEP-C=&%40T353-GE=&%40T353-LE=&WSER-C=&WLUG-C=&WDIS-C=%28DISPONIBLE+or+AGOTADO%29&WLEN-C=&WCLA-C=&WSOP-C="

               else
                 raise InvalidSearchTypeError
               end
        products = {}
        print "Request page is #{req}\n" if $DEBUG # for DEBUGing
        transport.get(URI.parse(req)).each do |line|
          #line = line.convert("ISO-8859-1", "UTF-8")
          print "Reading line: #{line}" if $DEBUG # for DEBUGing
          if (line =~ /CMD=VERDOC.*&DOCN=([^&]*)&NDOC=([^&]*)/) and (!products[$1]) and (book = parseBook($1,$2)) then
            products[$1] = book
            puts $1 if $DEBUG # for DEBUGing
          end
        end

        raise NoResultsError if products.values.empty?
        type == SEARCH_BY_ISBN ? products.values.first : products.values
      end

      def url(book)
        begin
          isbn = Library.canonicalise_isbn(book.isbn)
          "http://www.mcu.es/cgi-brs/BasesHTML/isbn/BRSCGI?CMD=VERLST&BASE=ISBN&DOCS=1-15&CONF=AEISPA.cnf&OPDEF=AND&DOCS=1&SEPARADOR=&WGEN-C=&WISB-C=#{isbn}&WAUT-C=&WTIT-C=&WMAT-C=&WEDI-C=&WFEP-C=&%40T353-GE=&%40T353-LE=&WSER-C=&WLUG-C=&WDIS-C=%28DISPONIBLE+or+AGOTADO%29&WLEN-C=&WCLA-C=&WSOP-C="
        rescue Exception => ex
          log.warn { "Cannot create url for book #{book}; #{ex.message}" }
          nil
        end
      end

      #######
      private
      #######

      def parseBook(docn,ndoc)
        detailspage='http://www.mcu.es/cgi-brs/BasesHTML/isbn/BRSCGI?CMD=VERDOC&CONF=AEISPA.cnf&BASE=ISBN&DOCN=' + docn + '&NDOC=' + ndoc
        print "Looking at detailspage: #{detailspage}\n" if $DEBUG # for DEBUGing
        product = {}
        product['authors'] = []
        nextline = nil
        robotstate = 0
        transport.get(URI.parse(detailspage)).each do |line|
          # This is a very crude robot interpreter
          # Note that the server provides more information
          # we don't store:
          # - Language  - Description
          # - Binding   - Price
          # - Colection - Theme
          # - CDU      - Last update

          # There seems to be an issue with accented chars..
          line = line.convert("UTF-8", "ISO-8859-1")
          print "Reading line (robotstate #{robotstate}): #{line}" if $DEBUG # for DEBUGing
          if line =~ /^<\/td>$/ or line =~ /^<\/tr>$/
            robotstate = 0
          elsif robotstate == 1 and line =~ /^([^<]+)</
            author = $1.gsub('&nbsp;',' ').sub(/ +$/,'')
            if author.length > 3 then
              # Only add authors of appropiate length
              product['authors'] << author
              print "Authors are #{product['authors']}\n" if $DEBUG # for DEBUGing
              robotstate = 0
            end
          elsif robotstate == 2 and line =~ /^(.*)$/ # The title es the next line to title declaration and has not tags on web src code
            product['name'] = $1.strip
            print "Name is #{product['name']}\n" if $DEBUG # for DEBUGing
            robotstate = 0
          elsif robotstate == 3 and line =~ /^([0-9]+-[0-9]+-[0-9]+-[0-9]+-[0-9]).*/
            product['isbn'] = $1
            print "ISBN is #{product['isbn']}\n" if $DEBUG # for DEBUGing
            robotstate = 0
          elsif robotstate == 4 and line =~ /^([^<]+)</
            product['manufacturer'] = $1.strip
            print "Manufacturer is #{product['manufacturer']}\n" if $DEBUG # for DEBUGing
            robotstate = 0
            #                elsif robotstate == 5 and line =~ /^([^<]+)</
          elsif robotstate == 5 and line =~ /<span>([^<]+)</
            product['media'] = $1.strip
            print "Media is #{product['media']}\n" if $DEBUG # for DEBUGing
            robotstate = 0
          elsif line =~ /^.*>Autor:\s*</
            robotstate = 1
          elsif line =~ /^.*>T(.|&iacute;)tulo:\s*</
            robotstate = 2
          elsif line =~ /^.*>ISBN \(13\):\s*</
            robotstate = 3
          elsif line =~ /^.*>Publicaci(.|&oacute;)n:\s*</
            robotstate = 4
          elsif line =~ /^.*>Encuadernaci(.|&oacute;)n:\s*</
            robotstate = 5
          end
        end

        # TODO: This provider does not include picture for books
        #            %w{name isbn media manufacturer}.each do |field|
        #               print "Checking #{field} for nil\n" if $DEBUG # for DEBUGing
        #                product[field]="" if product[field].nil?
        #            end

        print "Creating new book\n" if $DEBUG # for DEBUGing
        book = Book.new(product['name'],
                        product['authors'],
                        product['isbn'].delete('-'),
                        product['manufacturer'],
                        nil, # TODO: furnish publish year
                        product['media'])
        if book.title.nil?
          log.warn { "No title was returned for #{book.isbn}"}
          book.title = ''
        end
        return [ book ]
      end

    end
  end
end
