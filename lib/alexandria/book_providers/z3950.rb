# Copyright (C) 2005-2006 Laurent Sansonetti
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

$Z3950_DEBUG = $DEBUG

require 'zoom'
require 'marc'

module Alexandria
class BookProviders
    class Z3950Provider < AbstractProvider
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(name="Z3950", fullname="Z39.50")
            super
            prefs.add("hostname", _("Hostname"), "")
            prefs.add("port", _("Port"), 7090)
            prefs.add("database", _("Database"), "")
            prefs.add("record_syntax", _("Record syntax"), "USMARC", ["USMARC", "UNIMARC", "SUTRS"])
            prefs.add("username", _("Username"), "", nil, false)
            prefs.add("password", _("Password"), "", nil, false)
        end

        def search(criterion, type)
            prefs.read

            # We only decode MARC at the moment.
            # SUTRS needs to be decoded separately, because each Z39.50 server has a 
            # different one.
            unless marc?
                raise NoResultsError
            end

            criterion = Library.canonicalise_isbn(criterion) if type == SEARCH_BY_ISBN
            resultset = search_records(criterion, type, 10)
            puts "total #{resultset.length}" if $Z3950_DEBUG
            raise NoResultsError if resultset.length == 0
            results = books_from_marc(resultset)
            type == SEARCH_BY_ISBN ? results.first : results
        end

        def url(book)
            nil
        end
        
        #######
        private
        #######
        

        def books_from_marc(resultset)

            results = []
            resultset[0..9].each do |record|
                marc_txt = record.render(prefs['record_syntax'], 'USMARC')
                puts marc_txt  if $Z3950_DEBUG
                marc = MARC::Record.new(marc_txt)

                if $Z3950_DEBUG
                    puts "Parsing MARC"
                    puts "title: #{marc.title}"
                    puts "authors: #{marc.authors.join(', ')}"
                    puts "isbn: #{marc.isbn}"
                    puts "publisher: #{marc.publisher}"
                    puts "publish year: #{marc.publish_year}" if marc.respond_to?(:publish_year)
                    puts "edition: #{marc.edition}"
                end

                next if marc.title.nil? # or marc.authors.empty?
                if marc.isbn == nil
                    isbn = nil
                else
                    isbn = Library.canonicalise_ean(marc.isbn)
                end
                
                book = Book.new(marc.title, marc.authors, 
                                 isbn, 
                                (marc.publisher or ""),
                                marc.respond_to?(:publish_year) \
                                    ? marc.publish_year : nil,
                                (marc.edition or ""))
                results << [book]
            end
            return results
        end
        
        def marc?
            /MARC$/.match(prefs['record_syntax'])
        end
        
        def search_records(criterion, type, conn_count)
            options = {}
            unless prefs['username'].empty? or prefs['password'].empty?
                options['user'] = prefs['username']
                options['password'] = prefs['password']
            end
            hostname, port = prefs['hostname'], prefs['port'].to_i
            puts "hostname #{hostname} port #{port} options #{options}" if $Z3950_DEBUG
            conn = ZOOM::Connection.new(options).connect(hostname, port)
            conn.database_name = prefs['database']
            conn.preferred_record_syntax = prefs['record_syntax']
            conn.count = conn_count
            attr = case type
                when SEARCH_BY_ISBN     then [7]
                when SEARCH_BY_TITLE    then [4]
                when SEARCH_BY_AUTHORS  then [1, 1003]
                when SEARCH_BY_KEYWORD  then [1016]
            end
            pqf = ""
            attr.each { |attr| pqf += "@attr 1=#{attr} "}
            pqf += "\"" + criterion.upcase + "\""
            puts "pqf is #{pqf}, syntax #{prefs['record_syntax']}" if $Z3950_DEBUG
            conn.search(pqf)
        end
    end
    

    class LOCProvider < Z3950Provider
        # http://en.wikipedia.org/wiki/Library_of_Congress
        unabstract

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize
            super("LOC", _("Library of Congress (Usa)"))
            prefs.variable_named("hostname").default_value = "z3950.loc.gov"
            prefs.variable_named("port").default_value = 7090
            prefs.variable_named("database").default_value = "Voyager"
            prefs.variable_named("record_syntax").default_value = "USMARC"
        end

        def url(book)
            "http://catalog.loc.gov/cgi-bin/Pwebrecon.cgi?DB=local&CNT=25+records+per+page&CMD=isbn+" + Library.canonicalise_isbn(book.isbn)
        end
    end
    

    class BLProvider < Z3950Provider
        # http://en.wikipedia.org/wiki/Copac
        # http://en.wikipedia.org/wiki/British_Library
# FIXME: switch from BL to Copac, which incudes the BL itself and many more libraries: http://copac.ac.uk/libraries/
# Details: http://copac.ac.uk/interfaces/z39.50/
# The SUTRS format used by Copac is different from the one used by BL
        unabstract

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize
            super("BL", _("British Library"))
            prefs.variable_named("hostname").default_value = "z3950cat.bl.uk"
            prefs.variable_named("port").default_value = 9909
            prefs.variable_named("database").default_value = "BLAC"
            prefs.variable_named("record_syntax").default_value = "SUTRS"
        end
        
        def search(criterion, type)
            return super unless prefs['record_syntax'] == 'SUTRS'

            prefs.read
            criterion = Library.canonicalise_isbn(criterion) if type == SEARCH_BY_ISBN
            resultset = search_records(criterion, type, 10)
            puts "total #{resultset.length}" if $Z3950_DEBUG
            raise NoResultsError if resultset.length == 0
            results = books_from_sutrs(resultset)
            type == SEARCH_BY_ISBN ? results.first : results
        end

        def url(book)
            "http://copac.ac.uk/openurl?isbn=" + Library.canonicalise_isbn(book.isbn)
        end
        
        #######
        private
        #######
        
        def books_from_sutrs(resultset)
          results = []
          resultset[0..9].each do |record|
            text = record.render
            puts text if $Z3950_DEBUG

            title = isbn = publisher = publish_year = edition = nil
            authors = []
            
            text.split(/\n/).each do |line|
                if md = /^Title:\s+(.*)$/.match(line)
                    title = md[1].sub(/\.$/, '').squeeze(' ')
                elsif md = /^Added Person Name:\s+(.*),[^,]+$/.match(line)
                    authors << md[1]
                elsif md = /^ISBN:\s+([\dXx]+)/.match(line)
                    isbn = Library.canonicalise_ean( md[1] )
                elsif md = /^Imprint:.+\:\s*(.+)\,/.match(line)
                    publisher = md[1]
                end
            end

            if $Z3950_DEBUG
                puts "Parsing SUTRS"
                puts "title: #{title}"
                puts "authors: #{authors.join(' and ')}"
                puts "isbn: #{isbn}"
                puts "publisher: #{publisher}"
                puts "edition: #{edition}"
            end

            if title # and !authors.empty?
                book = Book.new(title, authors, isbn, (publisher or nil), (publish_year or nil), (edition or nil))
                results << [book]
            end

          end
          return results

        end
    end


    class SBNProvider < Z3950Provider
        # http://sbnonline.sbn.it/
        # http://it.wikipedia.org/wiki/ICCU
        unabstract

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize
            super("SBN", "Servizio Bibliotecario Nazionale (Italy)")
            prefs.variable_named("hostname").default_value = "opac.sbn.it"
            prefs.variable_named("port").default_value = 3950
            prefs.variable_named("database").default_value = "nopac"
            # supported 'USMARC', 'UNIMARC' , 'SUTRS'
            prefs.variable_named("record_syntax").default_value = "USMARC"
        end

        def search(criterion, type)
            prefs.read

            criterion = canonicalise_isbn_with_dashes(criterion)
            resultset = search_records(criterion, type, 0)
            puts "total #{resultset.length}" if $Z3950_DEBUG
            raise NoResultsError if resultset.length == 0
            results = books_from_marc(resultset)
            type == SEARCH_BY_ISBN ? results.first : results
        end

        def url(book)
            "http://sbnonline.sbn.it/cgi-bin/zgw/BRIEF.pl?displayquery=%253CB%253E%253Cfont%2520color%253D%2523000064%253E" +
            "Codice%2520ISBN%253C%2FB%253E%253C%2Ffont%253E%2520contiene%2520%2522%2520%253CFONT%2520COLOR%253Dred%253E" +
            canonicalise_isbn_with_dashes(book.isbn) +
            "%253C%2FFONT%253E%2522&session=&zurl=opac&zquery=%281%3D7+4%3D2+2%3D3+5%3D100+6%3D1+3%3D3+%22" +
            canonicalise_isbn_with_dashes(book.isbn) +
            "%22%29&language=it&maxentries=10&target=0&position=1"
        end

        #######
        private
        #######
        
        def canonicalise_isbn_with_dashes(isbn)
            # The reference for the position of the dashes is
            # http://www.isbn-international.org/converter/ranges.htm

            isbn = Alexandria::Library.canonicalise_isbn(isbn)

            if isbn[0..1] == "88"
                # Italian speaking area
                if isbn > "8895000" and isbn <="8899999996"
                    return isbn[0..1] + "-" + isbn[2..6] + "-" + isbn[7..8] + "-" + isbn[9..9]
                elsif isbn > "88900000"
                    return isbn[0..1] + "-" + isbn[2..7] + "-" + isbn[8..8] + "-" + isbn[9..9]
                elsif isbn > "8885000"
                    return isbn[0..1] + "-" + isbn[2..6] + "-" + isbn[7..8] + "-" + isbn[9..9]
                elsif isbn > "886000"
                    return isbn[0..1] + "-" + isbn[2..5] + "-" + isbn[6..8] + "-" + isbn[9..9]
                elsif isbn > "88200"
                    return isbn[0..1] + "-" + isbn[2..4] + "-" + isbn[5..8] + "-" + isbn[9..9]
                elsif isbn > "8800"
                    return isbn[0..1] + "-" + isbn[2..3] + "-" + isbn[4..8] + "-" + isbn[9..9]
                else
                    raise "Invalid ISBN"
                end

            else
                return isbn
            end
        end
=begin

Remarks about SBN

Problem:
- The code gets only the brief records, without ISBN, I don't knon how to get the full record.
- This provider requires that value of conn.count is 0. conn.count is not documented in Ruby/zoom.

Dashes:
this database requires that Italian books are searched with dashes :(
However, they have also books with dashes in wrong positions, for instance 88-061-4934-2

References:
http://sbnonline.sbn.it/zgw/homeit.html
http://www.iccu.sbn.it/genera.jsp?id=124
with link at http://www.iccu.sbn.it/upload/documenti/cartecsbn.pdf
which at page 5 or 6, it says
• Element-set-names: Full, R (the same as Full (because not detailed holding infos):
  according to Profile ONE-2), Brief (default, if client does not specify)
http://copac.ac.uk/interfaces/z39.50/zed-support/#esn
http://www.loc.gov/cgi-bin/zgstart?ACTION=INIT&FORM_HOST_PORT=/prod/www/data/z3950/iccu.html,opac.sbn.it,2100

http://gwz.cilea.it/cgi-bin/reportOpac.cgi

=end
    end

end
end
