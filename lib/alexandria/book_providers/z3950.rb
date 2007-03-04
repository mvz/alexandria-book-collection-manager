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
            prefs.add("record_syntax", _("Record syntax"), "USMARC", ["USMARC", "SUTRS", "UNIMARC"])
            prefs.add("username", _("Username"), "", nil, false)
            prefs.add("password", _("Password"), "", nil, false)
        end

        $Z3950_DEBUG = $DEBUG
       
        def search(criterion, type)
            prefs.read

            # We only decode MARC at the moment.
            # SUTRS needs to be decoded separately, because each Z39.50 server has a 
            # different one.
            unless marc?
                raise NoResultsError
            end

            resultset = search_records(criterion, type)
            puts "total #{resultset.length}" if $Z3950_DEBUG
            raise NoResultsError if resultset.length == 0
    
            results = []
            resultset[0..9].each do |record|
                marc_txt = record.render(prefs['record_syntax'], 'USMARC')
                marc = MARC::Record.new(marc_txt)

                if $Z3950_DEBUG
                    puts "MARC"
                    puts "title: #{marc.title}"
                    puts "authors: #{marc.authors.join(', ')}"
                    puts "isbn: #{marc.isbn}"
                    puts "publisher: #{marc.publisher}"
                    # puts "publish year: #{marc.publish_year}"
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
            type == SEARCH_BY_ISBN ? results.first : results
        end
        
        def url(book)
            nil
        end
        
        #######
        private
        #######
        
        def marc?
            /MARC$/.match(prefs['record_syntax'])
        end
        
        def search_records(criterion, type)
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
            conn.count = 10
            attr = case type
                when SEARCH_BY_ISBN     then [7]
                when SEARCH_BY_TITLE    then [4]
                when SEARCH_BY_AUTHORS  then [1, 1003]
                when SEARCH_BY_KEYWORD  then [1016]
            end
            pqf = ""
            attr.each { |attr| pqf += "@attr 1=#{attr} "}
            criterion = Library.canonicalise_isbn(criterion) if type == SEARCH_BY_ISBN
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
            super("LOC", _("Library of Congress"))
            prefs.variable_named("hostname").default_value = "z3950.loc.gov"
            prefs.variable_named("port").default_value = 7090
            prefs.variable_named("database").default_value = "Voyager"
            prefs.variable_named("record_syntax").default_value = "USMARC"
        end
    end
    
    class BLProvider < Z3950Provider
        # http://en.wikipedia.org/wiki/British_Library
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
            resultset = search_records(criterion, type)
            puts "total #{resultset.length}" if $Z3950_DEBUG
            raise NoResultsError if resultset.length == 0
            
            results = []
            resultset[0..9].each do |record|
                sutrs_text = record.render
                book = book_from_sutrs(sutrs_text)
                if book
                    results << [book]
                end
            end
            type == SEARCH_BY_ISBN ? results.first : results
        end
        
        #######
        private
        #######
        
        def book_from_sutrs(text)
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
                puts "SUTRS"
                puts "title: #{title}"
                puts "authors: #{authors.join(' and ')}"
                puts "isbn: #{isbn}"
                puts "publisher: #{publisher}"
                puts "edition: #{edition}"
            end

            if title # and !authors.empty?
                return Book.new(title, authors, isbn, (publisher or nil), (publish_year or nil), (edition or nil))
            end
        end
    end
end
end
