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
# write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301 USA.

require 'yaml'
require 'fileutils'
require 'rexml/document'
require 'tempfile'
require 'etc'
require 'open-uri'
require 'observer'
require 'singleton'

class Array
  def sum
    self.inject(0) { |a, b| a + b }
  end
end

module Alexandria
  class Library < Array
    include Logging

    attr_reader :name
    attr_accessor :ruined_books, :updating, :deleted_books
    DIR = File.join(ENV['HOME'], '.alexandria')
    EXT = { :book => '.yaml', :cover => '.cover' }

    include GetText
    extend GetText
    bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

    BOOK_ADDED, BOOK_UPDATED, BOOK_REMOVED = (0..3).to_a
    include Observable

    def path
      File.join(DIR, @name)
    end
    def updating?
      @updating
    end
    def self.generate_new_name(existing_libraries,
                               from_base=_("Untitled"))
      i = 1
      name = nil
      all_libraries = existing_libraries + @@deleted_libraries
      while true do
        name = i == 1 ? from_base : from_base + " #{i}"
        break unless all_libraries.find { |x| x.name == name }
        i += 1
      end
      return name
    end

    FIX_BIGNUM_REGEX =
      /loaned_since:\s*(\!ruby\/object\:Bignum\s*)?(\d+)\n/

    def self.load(name)
      test = [0,nil]
      ruined_books = []
      library = Library.new(name)
      FileUtils.mkdir_p(library.path) unless File.exists?(library.path)
      Dir.chdir(library.path) do
        Dir["*" + EXT[:book]].each do |filename|

          test[1] = filename if test[0] == 0

          if not File.size? test[1]
            log.warn { "Book file #{test[1]} was empty"}
            md = /([\dxX]{10,13})#{EXT[:book]}/.match(filename)
            if md
              file_isbn = md[1]
              ruined_books << [nil, file_isbn, library]
            else
              log.warn { "Filename #{filename} does not contain an ISBN"}
              #TODO delete this file...
            end
            next
          end
          book = self.regularize_book_from_yaml(test[1])
          old_isbn = book.isbn
          old_pub_year = book.publishing_year
          begin
            begin
              book.isbn = self.canonicalise_ean(book.isbn).to_s unless book.isbn == nil
              raise "Not a book: #{book.inspect}" unless book.is_a?(Book)
            rescue InvalidISBNError => e
              book.isbn = old_isbn
            end

            book.publishing_year = book.publishing_year.to_i unless book.publishing_year == nil

            # Or if isbn has changed
            raise "#{test[1]} isbn is not okay" unless book.isbn == old_isbn

            # Re-save book if Alexandria::DATA_VERSION changes
            raise "#{test[1]} version is not okay" unless book.version == Alexandria::DATA_VERSION

            # Or if publishing year has changed
            raise "#{test[1]} pub year is not okay" unless book.publishing_year == old_pub_year

            # ruined_books << [book, book.isbn, library]
            book.library = library.name

            ## TODO copy cover image file, if necessary
            # due to #26909 cover files for books without ISBN are re-saved as "g#{ident}.cover"
            if book.isbn == nil || book.isbn.empty?
              if File.exist? library.old_cover(book)
                log.debug { "#{library.name}; book #{book.title} has no ISBN, fixing cover image" }
                FileUtils::Verbose.mv(library.old_cover(book), library.cover(book))
              end
            end


            library << book
          rescue => e
            book.version = Alexandria::DATA_VERSION
            savedfilename = library.simple_save(book)
            test[0] = test[0] + 1
            test[1] = savedfilename

            # retries the Dir.each block...
            # but gives up after three tries
            redo unless test[0] > 2

          else
            test = [0,nil]
          end
        end

        # Since 0.4.0 the cover files '_small.jpg' and
        # '_medium.jpg' have been deprecated for a single medium
        # cover file named '.cover'.

        Dir["*" + '_medium.jpg'].each do |medium_cover|
          begin
            FileUtils.mv(medium_cover,
                         medium_cover.sub(/_medium\.jpg$/,
                                          EXT[:cover]))
          rescue
          end
        end



        Dir["*" + EXT[:cover]].each do |cover|
          next if cover[0] == 'g'
          md = /(.+)\.cover/.match(cover)
          begin
            ean = self.canonicalise_ean(md[1])
          rescue
            ean = md[1]
          end
          begin
            FileUtils.mv(cover, ean + EXT[:cover]) unless cover == ean + EXT[:cover]
          rescue
          end
        end

        FileUtils.rm_f(Dir['*_small.jpg'])
      end
      library.ruined_books = ruined_books

      library
    end

    def self.regularize_book_from_yaml(name)
      text = IO.read(name)

      #Code to remove the mystery string in books imported from Amazon
      # (In the past, still?) To allow ruby-amazon to be removed.

      # The string is removed on load, but can't make it stick, maybe has to do with cache

      if /!str:Amazon::Search::Response/.match(text)
        log.debug { "Removing Ruby/Amazon strings from #{name}" }
        text.gsub!("!str:Amazon::Search::Response", "")
      end

      # Backward compatibility with versions <= 0.6.0, where the
      # loaned_since field was a numeric.
      if md = FIX_BIGNUM_REGEX.match(text)
        new_yaml = Time.at(md[2].to_i).to_yaml
        # Remove the "---" prefix.
        new_yaml.sub!(/^\s*\-+\s*/, '')
        text.sub!(md[0], "loaned_since: #{new_yaml}\n")
      end
      book = YAML.load(text)
      unless book.isbn.class == String
        # HACK
        md = /isbn: (.+)/.match(text)
        if md
          string_isbn = md[1].strip
          book.isbn = string_isbn
        end
      end

      # another HACK of the same type as above
      unless book.saved_ident.class == String

        md2 = /saved_ident: (.+)/.match(text)
        if md2
          string_saved_ident = md2[1].strip
          log.debug { "fixing saved_ident #{book.saved_ident} -> #{string_saved_ident}" }
          book.saved_ident = string_saved_ident
        end
      end
      if book.isbn.class == String and book.isbn.length == 0
        book.isbn = nil # save trouble later
      end
      book
    end

    def self.loadall
      a = []
      begin
        Dir.entries(DIR).each do |file|
          # Skip hidden files.
          next if /^\./.match(file)
          # Skip non-directory files.
          next unless File.stat(File.join(DIR, file)).directory?

          a << self.load(file)
        end

      rescue Errno::ENOENT
        FileUtils.mkdir_p(DIR)
      end
      # Create the default library if there is no library yet.

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

    class NoISBNError < StandardError
      def initialize(msg)
        super(msg)
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
      raise NoISBNError.new("Nil ISBN") if isbn == nil || isbn.empty?

      isbn.delete('- ').upcase.split('').map do |x|
        raise InvalidISBNError.new(isbn) unless x =~ /[\dX]/
        x == 'X' ? 10 : x.to_i
      end
    end

    def self.isbn_checksum(numbers)
      sum = (0 ... numbers.length).inject(0) do |accumulator, i|
        accumulator + numbers[i] * (i + 1)
      end % 11

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
        (numbers.length == 13 and
         self.ean_checksum(numbers[0 .. 11]) == numbers[12]) or
          (numbers.length == 18 and
           self.ean_checksum(numbers[0 .. 11]) == numbers[12])
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
        (numbers.length == 17 and
         self.upc_checksum(numbers[0 .. 10]) == numbers[11])
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

    def self.canonicalise_ean(code)
      code = code.to_s.delete('- ')
      if self.valid_ean?(code)
        return code
      elsif self.valid_isbn?(code)
        code = "978" + code[0..8]
        return code + String( self.ean_checksum( self.extract_numbers( code ) ) )
      elsif self.valid_upc?(code)
        isbn10 =  self.canonicalise_isbn
        code = "978" + isbn10[0..8]
        return code + String( self.ean_checksum( self.extract_numbers( code ) ) )
        ## raise "fix function Alexandria::Library.canonicalise_ean"
      else
        raise InvalidISBNError.new(code)
      end
    end

    def self.canonicalise_isbn(isbn)
      numbers = self.extract_numbers(isbn)
      if self.valid_ean?(isbn)  and numbers[0 .. 2] != [9,7,8]
        return isbn
      end
      canonical = if self.valid_ean?(isbn)
                    # Looks like an EAN number -- extract the intersting part and
                    # calculate a checksum. It would be nice if we could validate
                    # the EAN number somehow.
                    numbers[3 .. 11] + [self.isbn_checksum(numbers[3 .. 11])]
                  elsif self.valid_upc?(isbn)
                    # Seems to be a valid UPC number.
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

    def simple_save(book)
      # Let's initialize the saved identifier if not already
      # (backward compatibility from 0.4.0)
      # book.saved_ident ||= book.ident
      if book.saved_ident.nil? or book.saved_ident.empty?
        book.saved_ident = book.ident()
      end
      if book.ident != book.saved_ident
        #log.debug { "Backwards compatibility step: #{book.saved_ident.inspect}, #{book.ident.inspect}" }
        FileUtils.rm(yaml(book.saved_ident))
      end
      if File.exists?(cover(book.saved_ident))
        begin
          FileUtils.mv(cover(book.saved_ident), cover(book.ident))
        rescue
        end
      end
      book.saved_ident = book.ident

      filename = book.saved_ident.to_s + ".yaml"
      File.open(filename, "w") { |io| io.puts book.to_yaml }
      filename
    end

    def save(book, final=false)
      changed unless final

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
        notify_observers(self, BOOK_UPDATED, book) unless final
        book.saved_ident = book.ident
      end
      ##was File.exists? but that returns true for empty files... CathalMagus
      already_there = (File.size?(yaml(book)) and
                       !@deleted_books.include?(book))
      
      temp_book=book.dup
      temp_book.library=nil
      File.open(yaml(temp_book), "w") { |io| io.puts temp_book.to_yaml }

      # Do not notify twice.
      if changed?
        notify_observers(self,
                         already_there ? BOOK_UPDATED : BOOK_ADDED,
                         book)
      end
    end

    def transport
      config = Alexandria::Preferences.instance.http_proxy_config
      config ? Net::HTTP.Proxy(*config) : Net::HTTP
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
            io.puts transport.get(uri)
          end
        end

        # Remove the file if its blank.
        if Alexandria::UI::Icons.blank?(cover_file)
          File.delete(cover_file)
        end
      end
    end

    @@deleted_libraries = []

    def self.deleted_libraries
      @@deleted_libraries
    end

    def self.really_delete_deleted_libraries
      @@deleted_libraries.each do |library|
        FileUtils.rm_rf(library.path)
      end
    end

    def really_delete_deleted_books
      @deleted_books.each do |book|
        [yaml(book), cover(book)].each do |file|
          FileUtils.rm_f(file)
        end
      end
    end

    alias_method :old_delete, :delete
    def delete(book=nil)
      if book.nil?
        # Delete the whole library.
        raise if @@deleted_libraries.include?(self)
        @@deleted_libraries << self
      else
        if @deleted_books.include?(book)
          doubles = @deleted_books.reject { |b| not b.equal? book }
          raise "Book #{book.isbn} was already deleted" unless doubles.empty?
        end
        @deleted_books << book
        i = self.index(book)
        puts "i is #{i.inspect}"
        # We check object IDs there because the user could have added
        # a book with the same identifier as another book he/she
        # previously deleted and that he/she is trying to redo.
        if i and self[i].equal? book
          changed
          old_delete(book) # FIX this will old_delete all '==' books
          notify_observers(self, BOOK_REMOVED, book)
        end
      end
    end

    def deleted?
      @@deleted_libraries.include?(self)
    end

    def undelete(book=nil)
      if book.nil?
        # Undelete the whole library.
        raise unless @@deleted_libraries.include?(self)
        @@deleted_libraries.delete(self)
      else
        raise unless @deleted_books.include?(book)
        @deleted_books.delete(book)
        unless self.include?(book)
          changed
          self << book
          notify_observers(self, BOOK_ADDED, book)
        end
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

    def old_cover(book)
      File.join(self.path, book.ident.to_s + EXT[:cover])
    end

    def cover(something)
      ident = case something
              when Book
                if (something.isbn && (not something.isbn.empty?))
                  something.ident
                else
                  "g#{something.ident}" # g is for generated id...
                end
              when String
                something
              when Bignum
                something
              when Fixnum
                something
              else
                raise "#{something} is a #{something.class}"
              end
      File.join(self.path, ident.to_s + EXT[:cover])
    end

    def yaml(something, basedir=self.path)
      ident = case something
              when Book
                something.ident
              when String
                something
              when Bignum
                something
              when Fixnum
                something
              else
                raise "#{something} is #{something.class}"
              end
      File.join(basedir, ident.to_s + EXT[:book])
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

    def copy_covers(somewhere)
      FileUtils.rm_rf(somewhere) if File.exists?(somewhere)
      FileUtils.mkdir(somewhere)
      each do |book|
        next unless File.exists?(cover(book))
        FileUtils.cp(cover(book),
                     File.join(somewhere, final_cover(book)))
      end
    end

    def self.jpeg?(file)
      'JFIF' == IO.read(file, 10)[6..9]
    end

    def final_cover(book)
      # TODO what about PNG?
      book.ident + (Library.jpeg?(cover(book)) ? '.jpg' : '.gif')
    end

    #########
    protected
    #########

    def initialize(name)
      @name = name
      @deleted_books = []
    end
  end

  class Libraries
    attr_reader :all_libraries, :ruined_books, :deleted_books

    include Observable
    include Singleton

    def reload
      @all_libraries.clear
      @all_libraries.concat(Library.loadall)
      @all_libraries.concat(SmartLibrary.loadall)
      
      ruined = []
      deleted = []
      last = []
      all_regular_libraries.each {|library|
        ruined += library.ruined_books
        #make deleted books from each library accessible so we don't crash on smart libraries
        deleted += library.deleted_books
      }
      @ruined_books = ruined
      @deleted_books = deleted
    end

    def all_regular_libraries
      @all_libraries.select { |x| x.is_a?(Library) }
    end

    def all_smart_libraries
      @all_libraries.select { |x| x.is_a?(SmartLibrary) }
    end
    
    #def all_dynamic_libraries
    #      @all_libraries.select { |x| x.is_a?(SmartLibrary) }
    #end

    LIBRARY_ADDED, LIBRARY_REMOVED = 1, 2

    def add_library(library)
      @all_libraries << library
      notify(LIBRARY_ADDED, library)
    end

    def remove_library(library)
      @all_libraries.delete(library)
      notify(LIBRARY_REMOVED, library)
    end

    def really_delete_deleted_libraries
      Library.really_delete_deleted_libraries
      SmartLibrary.really_delete_deleted_libraries
    end

    def really_save_all_books
      all_regular_libraries.each do |library|
        library.each {|book| library.save(book, true)}
      end
    end

    #######
    private
    #######

    def initialize
      @all_libraries = []
      @deleted_books = []
    end

    def notify(action, library)
      changed
      notify_observers(self, action, library)
    end
  end
end
