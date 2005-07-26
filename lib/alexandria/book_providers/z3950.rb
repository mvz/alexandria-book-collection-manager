# Copyright (C) 2005 Laurent Sansonetti
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
require 'zoom/marc'

module Alexandria
class BookProviders
    class Z3950Provider < AbstractProvider
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize
            super("Z3950", "Z39.50")
            prefs.add("hostname", _("Hostname"), "")
            prefs.add("port", _("Port"), 7090)
            prefs.add("database", _("Database"), "")
            prefs.add("username", _("Username"), "", nil, false)
            prefs.add("password", _("Password"), "", nil, false)
        end
       
        def search(criterion, type)
            prefs.read

            options = {}
            unless prefs['username'].empty? or prefs['password'].empty?
                options['user'] = prefs['username']
                options['password'] = prefs['password']
            end
            hostname, port = prefs['hostname'], prefs['port'].to_i
            conn = ZOOM::Connection.new(options).connect(hostname, port)
            conn.database_name = prefs['database']
            conn.preferred_record_syntax = 'USMARC'
            attr = case type
                when SEARCH_BY_ISBN     then 7
                when SEARCH_BY_TITLE    then 4
                when SEARCH_BY_AUTHORS  then 1003
                when SEARCH_BY_KEYWORD  then 1016
            end
            pqf = "@attr 1=#{attr} '#{criterion.upcase}'"
            puts "pqf is #{pqf}" if $DEBUG
            rset = conn.search(pqf)
            puts "total #{rset.length}" if $DEBUG
            raise NoResultsError if rset.length == 0
            results = []
            rset[0..10].each do |record|
                marc = MARC::Record.new(record.render)

                if $DEBUG
                    puts "title: #{marc.title}"
                    puts "authors: #{marc.authors.join(', ')}"
                    puts "isbn: #{marc.isbn}"
                    puts "publisher: #{marc.publisher}"
                    puts "edition: #{marc.edition}"
                end

                next if marc.title.nil? or marc.authors.empty?
                
                book = Book.new(marc.title, marc.authors, marc.isbn, 
                                (marc.publisher or ""), 
                                (marc.edition or ""))
                results << [book, nil]
            end
            type == SEARCH_BY_ISBN ? results.first : results
        end
    end
end
end
