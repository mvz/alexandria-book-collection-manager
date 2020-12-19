# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "yaml"
require "fileutils"
require "rexml/document"
require "tempfile"
require "etc"
require "alexandria/library_store"

module Alexandria
  class Library < Array
    include Logging

    attr_reader :name
    attr_accessor :ruined_books, :updating, :deleted_books

    DEFAULT_DIR = File.join(ENV["HOME"], ".alexandria")
    EXT = { book: ".yaml", cover: ".cover" }.freeze

    include GetText
    extend GetText
    bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

    BOOK_ADDED, BOOK_UPDATED, BOOK_REMOVED = (0..3).to_a
    include Observable

    def path
      File.join(@store.library_dir, @name)
    end

    def updating?
      @updating
    end

    def self.generate_new_name(existing_libraries,
                               from_base = _("Untitled"))
      i = 1
      name = nil
      all_libraries = existing_libraries + @@deleted_libraries
      loop do
        name = i == 1 ? from_base : from_base + " #{i}"
        break unless all_libraries.find { |x| x.name == name }

        i += 1
      end
      name
    end

    def self.move(source_library, dest_library, *books)
      dest = dest_library.path
      books.each do |book|
        FileUtils.mv(source_library.yaml(book), dest)
        if File.exist?(source_library.cover(book))
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

    def self.extract_numbers(entry)
      return [] if entry.nil? || entry.empty?

      normalized = entry.delete("- ").upcase
      return [] unless /\A[\dX]*\Z/.match?(normalized)

      normalized.split("").map do |char|
        char == "X" ? 10 : char.to_i
      end
    end

    def self.isbn_checksum(numbers)
      sum = (0...numbers.length).reduce(0) do |accumulator, i|
        accumulator + numbers[i] * (i + 1)
      end % 11

      sum == 10 ? "X" : sum
    end

    def self.valid_isbn?(isbn)
      numbers = extract_numbers(isbn)
      (numbers.length == 10) && isbn_checksum(numbers).zero?
    end

    def self.ean_checksum(numbers)
      -(numbers.values_at(1, 3, 5, 7, 9, 11).sum * 3 +
        numbers.values_at(0, 2, 4, 6, 8, 10).sum) % 10
    end

    def self.valid_ean?(ean)
      numbers = extract_numbers(ean)
      ((numbers.length == 13) &&
       (ean_checksum(numbers[0..11]) == numbers[12])) ||
        ((numbers.length == 18) &&
         (ean_checksum(numbers[0..11]) == numbers[12]))
    end

    def self.upc_checksum(numbers)
      -(numbers.values_at(0, 2, 4, 6, 8, 10).sum * 3 +
        numbers.values_at(1, 3, 5, 7, 9).sum) % 10
    end

    def self.valid_upc?(upc)
      numbers = extract_numbers(upc)
      ((numbers.length == 17) &&
       (upc_checksum(numbers[0..10]) == numbers[11]))
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
    }.freeze

    def self.upc_convert(upc)
      test_upc = upc.map(&:to_s).join
      extract_numbers(AMERICAN_UPC_LOOKUP[test_upc])
    end

    def self.canonicalise_ean(code)
      code = code.to_s.delete("- ")
      if valid_ean?(code)
        code
      elsif valid_isbn?(code)
        code = "978" + code[0..8]
        code + String(ean_checksum(extract_numbers(code)))
      elsif valid_upc?(code)
        isbn10 = canonicalise_isbn
        code = "978" + isbn10[0..8]
        code + String(ean_checksum(extract_numbers(code)))
      end
    end

    def self.canonicalise_isbn(isbn)
      numbers = extract_numbers(isbn)
      return isbn if valid_ean?(isbn) && (numbers[0..2] != [9, 7, 8])

      canonical = if valid_ean?(isbn)
                    # Looks like an EAN number -- extract the intersting part and
                    # calculate a checksum. It would be nice if we could validate
                    # the EAN number somehow.
                    numbers[3..11] + [isbn_checksum(numbers[3..11])]
                  elsif valid_upc?(isbn)
                    # Seems to be a valid UPC number.
                    prefix = upc_convert(numbers[0..5])
                    isbn_sans_chcksm = prefix + numbers[(8 + prefix.length)..17]
                    isbn_sans_chcksm + [isbn_checksum(isbn_sans_chcksm)]
                  elsif valid_isbn?(isbn)
                    # Seems to be a valid ISBN number.
                    numbers[0..-2] + [isbn_checksum(numbers[0..-2])]
                  end

      return unless canonical

      canonical.map(&:to_s).join
    end

    def simple_save(book)
      # Let's initialize the saved identifier if not already
      # (backward compatibility from 0.4.0)
      # book.saved_ident ||= book.ident
      book.saved_ident = book.ident if book.saved_ident.nil? || book.saved_ident.empty?
      if book.ident != book.saved_ident
        FileUtils.rm(yaml(book.saved_ident))
        if File.exist?(cover(book.saved_ident))
          FileUtils.mv(cover(book.saved_ident), cover(book.ident))
        end
      end
      book.saved_ident = book.ident

      filename = book.saved_ident.to_s + ".yaml"
      File.open(filename, "w") { |io| io.puts book.to_yaml }
      filename
    end

    def save(book, final = false)
      changed unless final

      # Let's initialize the saved identifier if not already
      # (backward compatibility from 0.4.0).
      book.saved_ident ||= book.ident

      if book.ident != book.saved_ident
        FileUtils.rm(yaml(book.saved_ident))
        if File.exist?(cover(book.saved_ident))
          FileUtils.mv(cover(book.saved_ident), cover(book.ident))
        end

        # Notify before updating the saved identifier, so the views
        # can still use the old one to update their models.
        notify_observers(self, BOOK_UPDATED, book) unless final
        book.saved_ident = book.ident
      end
      # #was File.exist? but that returns true for empty files... CathalMagus
      already_there = (File.size?(yaml(book)) &&
                       !@deleted_books.include?(book))

      temp_book = book.dup
      temp_book.library = nil
      File.open(yaml(temp_book), "w") { |io| io.puts temp_book.to_yaml }

      # Do not notify twice.
      return unless changed?

      notify_observers(self,
                       already_there ? BOOK_UPDATED : BOOK_ADDED,
                       book)
    end

    def transport
      config = Alexandria::Preferences.instance.http_proxy_config
      config ? Net::HTTP.Proxy(*config) : Net::HTTP
    end

    def save_cover(book, cover_uri)
      Dir.chdir(path) do
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
        File.delete(cover_file) if Alexandria::UI::Icons.blank?(cover_file)
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

    alias old_delete delete
    def delete(book = nil)
      if book.nil?
        # Delete the whole library.
        raise if @@deleted_libraries.include?(self)

        @@deleted_libraries << self
      else
        if @deleted_books.include?(book)
          doubles = @deleted_books.select { |b| b.equal?(book) }
          unless doubles.empty?
            raise ArgumentError, format(_("Book %<isbn>s was already deleted"),
                                        isbn: book.isbn)
          end
        end
        @deleted_books << book
        i = index(book)
        # We check object IDs there because the user could have added
        # a book with the same identifier as another book he/she
        # previously deleted and that he/she is trying to redo.
        if i && self[i].equal?(book)
          changed
          old_delete(book) # FIX this will old_delete all '==' books
          notify_observers(self, BOOK_REMOVED, book)
        end
      end
    end

    def deleted?
      @@deleted_libraries.include?(self)
    end

    def undelete(book = nil)
      if book.nil?
        # Undelete the whole library.
        raise unless @@deleted_libraries.include?(self)

        @@deleted_libraries.delete(self)
      else
        raise unless @deleted_books.include?(book)

        @deleted_books.delete(book)
        unless include?(book)
          changed
          self << book
          notify_observers(self, BOOK_ADDED, book)
        end
      end
    end

    alias old_select select
    def select
      filtered_library = Library.new(@name)
      each do |book|
        filtered_library << book if yield(book)
      end
      filtered_library
    end

    def old_cover(book)
      File.join(path, book.ident.to_s + EXT[:cover])
    end

    def cover(something)
      ident = case something
              when Book
                if something.isbn && !something.isbn.empty?
                  something.ident
                else
                  "g#{something.ident}" # g is for generated id...
                end
              when String, Integer
                something
              else
                raise NotImplementedError
              end
      File.join(path, ident.to_s + EXT[:cover])
    end

    def yaml(something, basedir = path)
      ident = case something
              when Book
                something.ident
              when String, Integer
                something
              else
                raise NotImplementedError
              end
      File.join(basedir, ident.to_s + EXT[:book])
    end

    def name=(name)
      File.rename(path, File.join(@store.library_dir, name))
      @name = name
    end

    def n_rated
      count { |x| !x.rating.nil? && x.rating > 0 }
    end

    def n_unrated
      length - n_rated
    end

    def ==(other)
      other.is_a?(self.class) && other.name == name
    end

    def copy_covers(somewhere)
      FileUtils.rm_rf(somewhere) if File.exist?(somewhere)
      FileUtils.mkdir(somewhere)
      each do |book|
        next unless File.exist?(cover(book))

        FileUtils.cp(cover(book),
                     File.join(somewhere, final_cover(book)))
      end
    end

    def self.jpeg?(file)
      IO.read(file, 10)[6..9] == "JFIF"
    end

    def final_cover(book)
      # TODO: what about PNG?
      book.ident + (Library.jpeg?(cover(book)) ? ".jpg" : ".gif")
    end

    protected

    def initialize(name, store = nil)
      @name = name
      @store = store
      @deleted_books = []
    end
  end
end
