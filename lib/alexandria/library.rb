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
require 'gdk_pixbuf2'
require 'open-uri'

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
 
        def path
            File.join(DIR, @name)
        end

        def self.load(name)
            library = Library.new(name)
            FileUtils.mkdir_p(library.path) unless File.exists?(library.path)
            Dir.chdir(library.path) do
                Dir["*" + EXT[:book]].each do |filename|
                    File.open(filename) do |io|
                        book = YAML.load(io)
                        raise "Not a book" unless book.is_a?(Book)
                        library << book
                    end
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
                    # skip '.', '..' and hidden files
                    next if file =~ /^\.+$/
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
            a
        end

        def self.move(source_library, dest_library, *books)
            dest = dest_library.path
            books.each do |book|
                FileUtils.mv(source_library.yaml(book), dest)
                if File.exists?(source_library.cover(book))
                    FileUtils.mv(source_library.cover(book), dest)
                end
                source_library.old_delete(book)
                dest_library.delete_if { |book2| book2.ident == book.ident }
                dest_library << book
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

            isbn.strip.delete('-').split('').map { |x|
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
                (numbers.length == 13 and self.ean_checksum(numbers) ==
                    numbers[12]) or
                (numbers.length == 18 and self.ean_checksum(numbers[0..12]) ==
                    numbers[12])
            rescue InvalidISBNError
                false
            end
        end

        def self.canonicalise_isbn(isbn)
            numbers = self.extract_numbers(isbn)

            canonical = if self.valid_ean?(isbn)
                # Looks like an EAN number -- extract the intersting part and
                # calculate a checksum. It would be nice if we could validate
                # the EAN number somehow.
                numbers[3 .. 11] + [self.isbn_checksum(numbers[3 .. 11])]
            elsif self.valid_isbn?(isbn)
                # Seems to be a valid ISBN number.
                numbers[0 .. -2] + [isbn_checksum(numbers[0 .. -2])]
            else
                raise InvalidISBNError.new(isbn)
            end

            canonical.map { |x| x.to_s }.join()
        end

        def save(book)
            if book.ident != book.saved_ident
                FileUtils.rm(yaml(book.saved_ident))
                if File.exists?(cover(book.saved_ident))
                    FileUtils.mv(cover(book.saved_ident), cover(book.ident)) 
                end
                book.saved_ident = book.ident
            end
            File.open(yaml(book), "w") { |io| io.puts book.to_yaml } 
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
                pixbuf = Gdk::Pixbuf.new(cover_file)
                if pixbuf.width == 1 and pixbuf.height == 1
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
                FileUtils.rm_f([yaml(book), cover(book)])
                old_delete(book)
            end
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
