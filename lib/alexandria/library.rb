# Copyright (C) 2004-2005 Laurent Sansonetti
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

require 'yaml'
require 'fileutils'
require 'rexml/document'
require 'tempfile'
require 'etc'
require 'open-uri'
require 'observer'

class Array
    def sum
        self.inject(0) { |a,b| a + b }
    end
end

module Alexandria
    class Library < Array
        attr_reader :name
        DIR = File.join(ENV['HOME'], '.alexandria')
        EXT = { :book => '.yaml', :cover => '.cover' }
        
        include GetText
        extend GetText
        bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        BOOK_ADDED, BOOK_UPDATED, BOOK_REMOVED = (0..3).to_a
        include Observable
    
        def path
            File.join(DIR, @name)
        end

        def self.generate_new_name(existing_libraries, 
                                   from_base=_("Untitled"))
            i = 1
            name = nil
            while true do
                name = i == 1 ? from_base : from_base + " #{i}"
                break unless existing_libraries.find { |x| x.name == name }
                i += 1
            end
            return name
        end

        def self.load(name)
            library = Library.new(name)
            FileUtils.mkdir_p(library.path) unless File.exists?(library.path)
            Dir.chdir(library.path) do
                Dir["*" + EXT[:book]].each do |filename|
                    text = IO.read(filename)
                    
                    # Backward compatibility with versions <= 0.6.0, where the 
                    # loaned_since field was a numeric.
                    if md = /loaned_since:\s*(\d+)\n/.match(text)
                        new_yaml = Time.at(md[1].to_i).to_yaml
                        # Remove the "---" prefix.
                        new_yaml.sub!(/^\s*\-+\s*/, '')
                        text.sub!(md[0], "loaned_since: #{new_yaml}\n")
                    end
 
                    book = YAML.load(text)
                    raise "Not a book" unless book.is_a?(Book)
                    library << book
                end

                # Since 0.4.0 the cover files '_small.jpg' and 
                # '_medium.jpg' have been deprecated for a single medium
                # cover file named '.cover'.
                Dir["*" + '_medium.jpg'].each do |medium_cover|
                    FileUtils.mv(medium_cover, 
                                 medium_cover.sub(/_medium\.jpg$/,
                                                  EXT[:cover]))
                end
                FileUtils.rm_f(Dir['*_small.jpg'])
            end
            library
        end
       
        def self.loadall
            a = []
            begin
                Dir.entries(DIR).each do |file|
                    # skip hidden files
                    next if /^\./.match(file)
                    # skip non-directory files
                    next unless File.stat(File.join(DIR, file)).directory?
    
                    a << self.load(file)       
                end
            rescue Errno::ENOENT
                FileUtils.mkdir_p(DIR)
            end
            # create the default library if there is no library yet 
            if a.empty?
                a << self.load(_("My Library"))
            end
            return a
        end

        def self.move(source_library, dest_library, *books)
            dest = dest_library.path
            books.each do |book|
                FileUtils.mv(source_library.yaml(book), dest)
                if File.exists?(source_library.cover(book))
                    FileUtils.mv(source_library.cover(book), dest)
                end

                source_library.changed
                source_library.old_delete(book)
                source_library.notify_observers(source_library, 
                                                BOOK_REMOVED, 
                                                book)

                dest_library.changed
                dest_library.delete_if { |book2| book2.ident == book.ident }
                dest_library << book
                dest_library.notify_observers(dest_library, BOOK_ADDED, book)
            end
        end

        class InvalidISBNError < StandardError
            attr_reader :isbn
            def initialize(isbn=nil)
                super()
                @isbn = isbn
            end
        end

        def self.extract_numbers(isbn)
            raise "Nil ISBN" if isbn == nil

            isbn.delete('- ').upcase.split('').map { |x|
                raise InvalidISBNError.new(isbn) unless x =~ /[\dX]/
                x == 'X' ? 10 : x.to_i
            }
        end

        def self.isbn_checksum(numbers)
            sum = (0 ... numbers.length).inject(0) { |accumulator,i|
                accumulator + numbers[i] * (i + 1)
            } % 11

            sum == 10 ? 'X' : sum
        end

        def self.valid_isbn?(isbn)
            begin
                numbers = self.extract_numbers(isbn)
                numbers.length == 10 and self.isbn_checksum(numbers) == 0
            rescue InvalidISBNError
                false
            end
        end

        def self.ean_checksum(numbers)
            (10 - ([1, 3, 5, 7, 9, 11].map { |x| numbers[x] }.sum * 3 +
                  [0, 2, 4, 6, 8, 10].map { |x| numbers[x] }.sum)) % 10
        end

        def self.valid_ean?(ean)
            begin
                numbers = self.extract_numbers(ean)
                (numbers.length == 13 and self.ean_checksum(numbers[0 .. 11]) ==
                    numbers[12]) or
                (numbers.length == 18 and self.ean_checksum(numbers[0 .. 11]) ==
                    numbers[12])
            rescue InvalidISBNError
                false
            end
        end

        def self.upc_checksum(numbers)
            (10 - ([0, 2, 4, 6, 8, 10].map { |x| numbers[x] }.sum * 3 +
                  [1, 3, 5, 7, 9].map { |x| numbers[x] }.sum)) % 10
        end

        def self.valid_upc?(upc)
            begin
                numbers = self.extract_numbers(upc)
                (numbers.length == 17 and self.upc_checksum(numbers[0 .. 10]) ==
                    numbers[11])
            rescue InvalidISBNError
                false
            end
        end

	    AMERICAN_UPC_LOOKUP = {
            "014794" => "08041", "018926" => "0445", "02778" => "0449",
            "037145" => "0812", "042799" => "0785",  "043144" => "0688",
            "044903" => "0312", "045863" => "0517", "046594" => "0064",
            "047132" => "0152", "051487" => "08167", "051488" => "0140",
            "060771" => "0002", "065373" => "0373", "070992" => "0523",
            "070993" => "0446", "070999" => "0345", "071001" => "0380",
            "071009" => "0440", "071125" => "088677", "071136" => "0451",
            "071149" => "0451", "071152" => "0515", "071162" => "0451",
            "071268" => "08217", "071831" => "0425", "071842" => "08439",
            "072742" => "0441", "076714" => "0671", "076783" => "0553",
            "076814" => "0449", "078021" => "0872", "079808" => "0394",
            "090129" => "0679", "099455" => "0061", "099769" => "0451"
            }

        def self.upc_convert(upc)
            test_upc = upc.map { |x| x.to_s }.join()
            self.extract_numbers(AMERICAN_UPC_LOOKUP[test_upc])
        end

        def self.canonicalise_isbn(isbn)
            numbers = self.extract_numbers(isbn)

            canonical = if self.valid_ean?(isbn)
                # Looks like an EAN number -- extract the intersting part and
                # calculate a checksum. It would be nice if we could validate
                # the EAN number somehow.
                numbers[3 .. 11] + [self.isbn_checksum(numbers[3 .. 11])]
            elsif self.valid_upc?(isbn)
                # Seems to be a valid UPC number
                prefix = self.upc_convert(numbers[0 .. 5])
                isbn_sans_chcksm = prefix + numbers[(8 + prefix.length) .. 17]
                isbn_sans_chcksm + [self.isbn_checksum(isbn_sans_chcksm)]
            elsif self.valid_isbn?(isbn)
                # Seems to be a valid ISBN number.
                numbers[0 .. -2] + [self.isbn_checksum(numbers[0 .. -2])]
            else
                raise InvalidISBNError.new(isbn)
            end

            canonical.map { |x| x.to_s }.join()
        end

        def save(book)
            changed
            
            # Let's initialize the saved identifier if not already
            # (backward compatibility from 0.4.0).
            book.saved_ident ||= book.ident

            if book.ident != book.saved_ident
                FileUtils.rm(yaml(book.saved_ident))
                if File.exists?(cover(book.saved_ident))
                    FileUtils.mv(cover(book.saved_ident), cover(book.ident))
                end
    
                # Notify before updating the saved identifier, so the views
                # can still use the old one to update their models.
                notify_observers(self, BOOK_UPDATED, book)
                book.saved_ident = book.ident
            end
            yaml_exists = File.exists?(yaml(book))
            File.open(yaml(book), "w") { |io| io.puts book.to_yaml }
            
            # Do not notify twice.
            if changed? 
                notify_observers(self, 
                                 yaml_exists ? BOOK_UPDATED : BOOK_ADDED, 
                                 book)
            end
        end

        def save_cover(book, cover_uri)
            Dir.chdir(self.path) do
                # Fetch the cover picture.
                cover_file = cover(book)
                File.open(cover_file, "w") do |io|
                    uri = URI.parse(cover_uri)
                    if uri.scheme.nil?
                        # Regular filename.
                        File.open(cover_uri) { |io2| io.puts io2.read }
                    else
                        # Try open-uri.
                        io.puts uri.read
                    end
                end
            
                # Remove the file if it's blank.
                if Alexandria::UI::Icons.blank?(cover_file)
                    File.delete(cover_file)
                end
            end
        end
        
        alias_method :old_delete, :delete
        def delete(book=nil)
            if book.nil?
                # delete the whole library
                FileUtils.rm_rf(self.path)
            else
                changed
                FileUtils.rm_f([yaml(book), cover(book)])
                old_delete(book)
                notify_observers(self, BOOK_REMOVED, book)
            end
        end

        alias_method :old_select, :select
        def select
            filtered_library = Library.new(@name)
            self.each do |book|
                filtered_library << book if yield(book)
            end
            return filtered_library
        end

        def cover(something)
            ident = case something
                when Book
                    something.ident
                when String
                    something
                else
                    raise
            end
            File.join(self.path, ident + EXT[:cover])
        end
    
        def yaml(something)
            ident = case something
                when Book
                    something.ident
                when String
                    something
                else
                    raise
            end
            File.join(self.path, ident + EXT[:book])
        end
        
        def name=(name)
            File.rename(path, File.join(DIR, name))
            @name = name
        end

        def n_rated
            select { |x| !x.rating.nil? and x.rating > 0 }.length
        end
       
        def n_unrated
            length - n_rated
        end
        
        def ==(object)
            object.is_a?(self.class) && object.name == self.name
        end
        
        #######
        private
        #######

        def initialize(name)
            @name = name
        end

        def copy_covers(somewhere)
            FileUtils.rm_rf(somewhere) if File.exists?(somewhere)
            FileUtils.mkdir(somewhere)
            each do |book|
                next unless File.exists?(cover(book))
                FileUtils.cp(File.join(self.path, book.ident + EXT[:cover]),
                             File.join(somewhere, final_cover(book))) 
            end
        end

        def jpeg?(file)
            'JFIF' == IO.read(file, 10)[6..9]
        end

        def final_cover(book)
            book.ident + (jpeg?(cover(book)) ? '.jpg' : '.gif')
        end
    end
end
