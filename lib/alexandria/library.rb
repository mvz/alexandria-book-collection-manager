# Copyright (C) 2004 Laurent Sansonetti
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
            begin
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
            rescue Errno::ENOENT
                FileUtils.mkdir_p(library.path)
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
            end
        end
        
        def self.extract_numbers(isbn)
            raise "Invalid ISBN '#{isbn}'" if isbn == nil

            isbn.strip.delete('-').split('').map { |x|
                raise "Invalid ISBN '#{isbn}'" unless x =~ /[\dX]/
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
            rescue
                false
            end
        end

        def self.ean_checksum(numbers)
                10 - ([1, 3, 5, 7, 9, 11].map { |x| numbers[x] }.sum * 3 +
                      [0, 2, 4, 6, 8, 10].map { |x| numbers[x] }.sum) % 10
        end

        def self.valid_ean?(ean)
            begin
                numbers = self.extract_numbers(ean)
                (numbers.length == 13 and self.ean_checksum(numbers) ==
                    numbers[12]) or
                (numbers.length == 18 and self.ean_checksum(numbers[0..12]) ==
                    numbers[12])
            rescue
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
                raise "Invalid ISBN number '#{isbn}'."
            end

            canonical.map { |x| x.to_s }.join()
        end

        def save(book, new_isbn=nil)
            if new_isbn and book.isbn != new_isbn
                FileUtils.rm(yaml(book))
                FileUtils.mv(cover(book), cover(new_isbn)) 
                book.isbn = new_isbn
            end
            File.open(yaml(book), "w") { |io| io.puts book.to_yaml } 
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
            isbn = case something
                when Book
                    something.isbn
                when String
                    something
                else
                    raise
            end
            File.join(self.path, isbn + EXT[:cover])
        end
    
        def yaml(book)
            File.join(self.path, book.isbn + EXT[:book])
        end
        
        def name=(name)
            File.rename(path, File.join(DIR, name))
            @name = name
        end

        def export_as_onix_xml_archive(filename)
            filename += ".onix.tbz2" if File.extname(filename).empty?
            File.open(File.join(Dir.tmpdir, "onix.xml"), "w") do |io|
                to_onix_document.write(io, 0)
            end
            copy_covers(File.join(Dir.tmpdir, "images"))
            Dir.chdir(Dir.tmpdir) do  
                system("tar -cjf \"#{filename}\" onix.xml images")
            end
            FileUtils.rm_rf(File.join(Dir.tmpdir, "images"))
            FileUtils.rm(File.join(Dir.tmpdir, "onix.xml"))
        end

        def export_as_tellico_xml_archive(filename)
            filename += ".bc" if File.extname(filename).empty?
            if File.exists?(filename)
                FileUtils.rm(filename)
            end
            File.open(File.join(Dir.tmpdir, "bookcase.xml"), "w") do |io|
                to_tellico_document.write(io, 0)
            end
            copy_covers(File.join(Dir.tmpdir, "images"))
            Dir.chdir(Dir.tmpdir) do
                system("zip -q -r \"#{filename}\" bookcase.xml images")
            end
            FileUtils.rm_rf(File.join(Dir.tmpdir, "images"))
            FileUtils.rm(File.join(Dir.tmpdir, "bookcase.xml"))
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

        ONIX_DTD_URL = "http://www.editeur.org/onix/2.1/reference/onix-international.dtd"
        def to_onix_document
            doc = REXML::Document.new
            doc << REXML::XMLDecl.new
            doc << REXML::DocType.new('ONIXMessage', 
                                      "SYSTEM \"#{ONIX_DTD_URL}\"")
            msg = doc.add_element('ONIXMessage')
            header = msg.add_element('Header')
            now = Time.now
            header.add_element('SentDate').text = "%.4d%.2d%.2d%.2d%.2d" % [ 
                now.year, now.month, now.day, now.hour, now.min 
            ]
            header.add_element('FromPerson').text = Etc.getlogin
            header.add_element('MessageNote').text = name
            each_with_index do |book, idx|
                # fields that are missing: edition and rating.
                prod = msg.add_element('Product')
                prod.add_element('RecordSourceName').text = 
                    "Alexandria " + VERSION
                prod.add_element('RecordReference').text = idx.to_s
                prod.add_element('NotificationType').text = "03"  # confirmed
                prod.add_element('ProductForm').text = 'BA'       # book
                prod.add_element('ISBN').text = book.isbn
                prod.add_element('DistinctiveTitle').text = book.title
                unless book.authors.empty?
                    book.authors.each do |author|
                        elem = prod.add_element('Contributor')
                        # author
                        elem.add_element('ContributorRole').text = 'A01'
                        elem.add_element('PersonName').text = author
                    end
                end
                prod.add_element('PublisherName').text = book.publisher
                if book.notes and not book.notes.empty?
                    elem = prod.add_element('OtherText')
                    # reader description
                    elem.add_element('TextTypeCode').text = '12' 
                    elem.add_element('TextFormat').text = '00'  # ASCII
                    elem.add_element('Text').text = book.notes 
                end
                if File.exists?(cover(book))
                    elem = prod.add_element('MediaFile')
                    # front cover image
                    elem.add_element('MediaFileTypeCode').text = '04'
                    # JPEG (FIXME may be GIF is bn.com is used)
                    elem.add_element('MediaFileFormatCode').text = '03'
                    # filename
                    elem.add_element('MediaFileLinkTypeCode').text = '06'
                    elem.add_element('MediaFileLink').text = 
                        File.join('images', book.isbn + EXT[:cover])
                end
                BookProviders.each do |provider|
                    elem = prod.add_element('ProductWebSite')
                    elem.add_element('ProductWebsiteDescription').text = 
                        provider.fullname
                    elem.add_element('ProductWebsiteLink').text = 
                        provider.url(book)
                end
            end
            return doc
        end

        def to_tellico_document
            doc = REXML::Document.new
            doc << REXML::XMLDecl.new
            doc << REXML::DocType.new('bookcase', "SYSTEM \"bookcase.dtd\"")
            bookcase = doc.add_element('bookcase')
            bookcase.add_namespace('http://www.periapsis.org/bookcase/')
            bookcase.add_attribute('syntaxVersion', "5")
            collection = bookcase.add_element('collection')
            collection.add_attribute('title', self.name)
            collection.add_attribute('type', "2")
            fields = collection.add_element('fields')
            field1 = fields.add_element('field')
            # a field named _default implies adding all default book 
            # collection fields
            field1.add_attribute('name', "_default")
            # make the rating field just have numbers
            field2 = fields.add_element('field')
            field2.add_attribute('name', "rating")
            field2.add_attribute('title', _("Rating"))
            field2.add_attribute('flags', "2")
            field2.add_attribute('category', "Personal")
            field2.add_attribute('format', "0")
            field2.add_attribute('type', "3")
            field2.add_attribute('allowed', "5;4;3;2;1")
            images = collection.add_element('images')
            each_with_index do |book, idx|
                entry = collection.add_element('entry')
                # translate the binding
                entry.add_attribute('i18n', "true")
                entry.add_element('title').text = book.title
                entry.add_element('isbn').text = book.isbn
                entry.add_element('binding').text = book.edition
                entry.add_element('publisher').text = book.publisher
                unless book.authors.empty?
                    authors = entry.add_element('authors')
                    book.authors.each do |author|
                        authors.add_element('author').text = author
                    end
                end
                if not book.rating = Book::DEFAULT_RATING
                    entry.add_element('rating').text = book.rating
                end
                if book.notes and not book.notes.empty?
                    entry.add_element('comments').text = book.notes
                end
                if File.exists?(cover(book))
                    entry.add_element('cover').text = book.isbn + EXT[:cover]
                    image = images.add_element('image')
                    image.add_attribute('id', book.isbn + EXT[:cover])
                    image.add_attribute('format', "JPEG")
                end
            end
            return doc
        end
        
        def copy_covers(somewhere)
            # remove tmp dir first
            FileUtils.rm_rf(somewhere) if File.exists?(somewhere)
            FileUtils.mkdir(somewhere)
            Dir.chdir(self.path) do
                FileUtils.cp(Dir.glob('*' + EXT[:cover]), somewhere)
            end
        end
    end
end
