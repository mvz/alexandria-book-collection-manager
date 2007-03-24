# Copyright (C) 2004-2006 Laurent Sansonetti
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
require 'gettext'

module Alexandria
    class ImportFilter
        attr_reader :name, :patterns, :message

        include GetText
        extend GetText
        bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
        
        def self.all
            [
                self.new(_("Autodetect"), ['*'], :import_autodetect),
                self.new(_("Archived Tellico XML (*.bc, *.tc)"), 
                         ['*.tc', '*.bc'], :import_as_tellico_xml_archive),
                self.new(_("ISBN List (*.txt)"), ['*.txt'],
                         :import_as_isbn_list)
            ]
        end
   
        def on_iterate(&on_iterate_cb)
            @on_iterate_cb = on_iterate_cb
        end

        def on_error(&on_error_cb)
            @on_error_cb = on_error_cb
        end
   
        def invoke(library_name, filename)
        	puts "Selected: #{@message} -- #{library_name} -- #{filename}"
            Library.send(@message, library_name, filename,
                         @on_iterate_cb, @on_error_cb)
        end
        
        #######
        private
        #######

        def initialize(name, patterns, message)
            @name = name
            @patterns = patterns
            @message = message
        end
    end

    class Library
        def self.import_autodetect(*args)
        	puts args.inspect
        	filename = args[1]
        	puts "Filename is #{filename} and ext is #{filename[-4..-1]}"
        	puts "Beginning import: #{args[0]}, #{args[1]}"
        	if filename[-4..-1] == ".txt"
            	self.import_as_isbn_list(*args)
            elsif [".tc",".bc"].include? filename[-3..-1]
            	begin 
            	self.import_as_tellico_xml_archive(*args)
            	rescue => e
            		puts e.message
            	end
            else
            	puts "Bailing on this import!"
            	raise "Not supported type"
            end
        end
        
        def self.import_as_tellico_xml_archive(name, filename,
                                               on_iterate_cb, on_error_cb)
            puts "Starting import_as_tellico_xml_archive... "
            return nil unless system("unzip -qqt \"#{filename}\"")
            tmpdir = File.join(Dir.tmpdir, "tellico_export")
            FileUtils.rm_rf(tmpdir) if File.exists?(tmpdir)
            Dir.mkdir(tmpdir)
            Dir.chdir(tmpdir) do
                begin
                    system("unzip -qq \"#{filename}\"")
                    file = File.exists?('bookcase.xml') \
                        ? 'bookcase.xml' : 'tellico.xml'
                    xml = REXML::Document.new(File.open(file))
                    raise unless (xml.root.name == 'bookcase' or 
                                  xml.root.name == 'tellico')
                    # FIXME: handle multiple collections
                    raise unless xml.root.elements.size == 1
                    collection = xml.root.elements[1]
                    raise unless collection.name == 'collection'
                    type = collection.attribute('type').value.to_i
		            raise unless (type == 2 or type == 5)
                    
                    content = []
                    entries = collection.elements.to_a('entry')
                    (total = entries.size).times do |n|
                        entry = entries[n]
                        elements = entry.elements
                        #Feed an array in here, tomorrow.
                        keys = ['isbn', 'publisher', 'pub_year', 'binding']
                        
                        book_elements = [elements['title'].text]
                        if elements['authors'] != nil
                            book_elements += [elements['authors'].elements.to_a.map \
                                            { |x| x.text }]
                        else
                            book_elements += [[]]
                        end
                        book_elements += keys.map {|key| 
                        					unless elements[key]
                        						nil
                        					else
                        						elements[key].text
                        					end
                        					}
                     	puts book_elements.inspect
                     	if elements['cover']
                       		cover = elements['cover'].text
                       	else
                       		cover = nil
                       	end
                       	puts cover 
                        book = Book.new(*book_elements)
                        content << [ book, cover]
                        on_iterate_cb.call(n+1, total) if on_iterate_cb
                    end

                    library = Library.load(name)
                    content.each do |book, cover|
                        unless cover.nil?
                            library.save_cover(book, 
                                               File.join(Dir.pwd, "images", 
                                                         cover))
                        end
                        library << book
                        library.save(book)
                    end
                    return [library, []]
                rescue => e
                	puts e.message
                    return nil
                end
            end
        end
        
        def self.import_as_isbn_list(name, filename, on_iterate_cb, 
                                     on_error_cb)
            puts "Starting import_as_isbn_list... "
            isbn_list = IO.readlines(filename).map do |line|
            	puts "Trying line #{line}" if $DEBUG
            	# Let's preserve the failing isbns so we can report them later.
            	begin
                	[line.chomp, canonicalise_isbn(line.chomp)] unless line == "\n"
                rescue => e
                	puts e.message 
                	[line.chomp, nil]
                end
            end 
            puts "Isbn list: #{isbn_list.inspect}"
            isbn_list.compact!
            return nil if isbn_list.empty?
            max_iterations = isbn_list.length * 2
            current_iteration = 1
            books = []
            bad_isbns = []
            isbn_list.each do |isbn|
                begin
                	unless isbn[1]
                		bad_isbns << isbn[0]
                	else
                    	books << Alexandria::BookProviders.isbn_search(isbn[1])
                    end
                rescue => e
                	puts e.message
                    return nil unless
                        (on_error_cb and on_error_cb.call(e.message))
                end

                on_iterate_cb.call(current_iteration += 1, 
                                   max_iterations) if on_iterate_cb
            end
            puts "Bad Isbn list: #{bad_isbns.inspect}" if bad_isbns
            library = load(name)
            puts "Going with these #{books.length} books: #{books.inspect}" if $DEBUG
            books.each do |book, cover_uri|
            	puts "Saving #{book.isbn} cover..." if $DEBUG
                library.save_cover(book, cover_uri) if cover_uri != nil
                puts "Saving #{book.isbn}..." if $DEBUG
                library << book
                library.save(book)
                on_iterate_cb.call(current_iteration += 1, 
                                   max_iterations) if on_iterate_cb
            end
            return [library, bad_isbns]
        end
    end
end
