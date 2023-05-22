# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  class LibraryStore
    include Logging

    FIX_BIGNUM_REGEX =
      %r{loaned_since:\s*(!ruby/object:Bignum\s*)?(\d+)\n}

    include GetText
    bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

    def initialize(dir)
      @dir = dir
    end

    def load_all_libraries
      a = []
      begin
        Dir.entries(library_dir).each do |file|
          # Skip hidden files.
          next if file.start_with?(".")
          # Skip non-directory files.
          next unless File.stat(File.join(library_dir, file)).directory?

          a << load_library(file)
        end
      rescue Errno::ENOENT
        FileUtils.mkdir_p(library_dir)
      end

      # Create the default library if there is no library yet.
      a << load_library(_("My Library")) if a.empty?

      a
    end

    def load_library(name)
      test = [0, nil]
      ruined_books = []
      library = Library.new(name, self)
      FileUtils.mkdir_p(library.path)
      Dir.chdir(library.path) do
        Dir["*" + Library::EXT[:book]].each do |filename|
          test[1] = filename if (test[0]).zero?

          unless File.size? test[1]
            handle_empty_book_file(test[1], ruined_books)
            next
          end
          book = regularize_book_from_yaml(test[1])
          old_isbn = book.isbn
          old_pub_year = book.publishing_year
          begin
            raise format(_("Not a book: %<book>s"), book.inspect) unless book.is_a?(Book)

            ean = Library.canonicalise_ean(book.isbn)
            book.isbn = ean if ean

            unless book.publishing_year.nil?
              book.publishing_year = book.publishing_year.to_i
            end

            # Or if isbn has changed
            unless book.isbn == old_isbn
              raise format(_("%<file>s isbn is not okay"), file: test[1])
            end

            # Re-save book if Alexandria::DATA_VERSION changes
            unless book.version == Alexandria::DATA_VERSION
              raise format(_("%<file>s version is not okay"), file: test[1])
            end

            # Or if publishing year has changed
            unless book.publishing_year == old_pub_year
              raise format(_("%<file>s pub year is not okay"), file: test[1])
            end

            # ruined_books << [book, book.isbn, library]
            book.library = library.name

            ## TODO copy cover image file, if necessary
            # due to #26909 cover files for books without ISBN are re-saved as
            # "g#{ident}.cover"
            if (book.isbn.nil? || book.isbn.empty?) && File.exist?(library.old_cover(book))
              log.debug do
                "#{library.name}; book #{book.title} has no ISBN, fixing cover image"
              end
              FileUtils::Verbose.mv(library.old_cover(book), library.cover(book))
            end

            library << book
          rescue StandardError
            book.version = Alexandria::DATA_VERSION
            savedfilename = library.simple_save(book)
            test[0] = test[0] + 1
            test[1] = savedfilename

            # retries the Dir.each block...
            # but gives up after three tries
            redo unless test[0] > 2
          else
            test = [0, nil]
          end
        end

        # Since 0.4.0 the cover files '_small.jpg' and
        # '_medium.jpg' have been deprecated for a single medium
        # cover file named '.cover'.

        Dir["*" + "_medium.jpg"].each do |medium_cover|
          FileUtils.mv(medium_cover,
                       medium_cover.sub(/_medium\.jpg$/,
                                        Library::EXT[:cover]))
        end

        Dir["*" + Library::EXT[:cover]].each do |cover|
          next if cover[0] == "g"

          md = /(.+)\.cover/.match(cover)
          ean = Library.canonicalise_ean(md[1]) || md[1]
          unless cover == ean + Library::EXT[:cover]
            FileUtils.mv(cover, ean + Library::EXT[:cover])
          end
        end

        FileUtils.rm_f(Dir["*_small.jpg"])
      end
      library.ruined_books = ruined_books

      library
    end

    def load_all_smart_libraries
      a = []
      begin
        # Deserialize smart libraries.
        Dir.chdir(smart_library_dir) do
          Dir["*" + SmartLibrary::EXT].each do |filename|
            # Skip non-regular files.
            next unless File.stat(filename).file?

            text = File.read(filename)
            hash = YAML.safe_load(text, permitted_classes: [Symbol])
            smart_library = SmartLibrary.from_hash(hash, self)
            a << smart_library
          end
        end
      rescue Errno::ENOENT
        # First run and no smart libraries yet? Provide some default
        # ones.
        SmartLibrary.sample_smart_libraries(self).each do |smart_library|
          smart_library.save
          a << smart_library
        end
      end
      a.each(&:refilter)
      a
    end

    def library_dir
      @dir
    end

    def smart_library_dir
      File.join(@dir, ".smart_libraries")
    end

    private

    def handle_empty_book_file(filename, ruined_books)
      log.warn { "Book file #{filename} was empty" }
      md = /([\dxX]{10,13})#{Library::EXT[:book]}/.match(filename)
      if md
        file_isbn = md[1]
        ruined_books << file_isbn
      else
        log.warn { "Filename #{filename} does not contain an ISBN" }
        # TODO: delete this file...
      end
    end

    def regularize_book_from_yaml(name)
      text = File.read(name)

      # Code to remove the mystery string in books imported from Amazon
      # (In the past, still?) To allow ruby-amazon to be removed.

      # The string is removed on load, but can't make it stick, maybe has to do with cache

      if text.include?("!str:Amazon::Search::Response")
        log.debug { "Removing Ruby/Amazon strings from #{name}" }
        text.gsub!("!str:Amazon::Search::Response", "")
      end

      # Backward compatibility with versions <= 0.6.0, where the
      # loaned_since field was a numeric.
      if (md = FIX_BIGNUM_REGEX.match(text))
        new_yaml = Time.at(md[2].to_i).to_yaml
        # Remove the "---" prefix.
        new_yaml.sub!(/^\s*-+\s*/, "")
        text.sub!(md[0], "loaned_since: #{new_yaml}\n")
      end

      book = Book.from_yaml(text)

      unless book.isbn.instance_of? String
        # HACK
        md = /isbn: (.+)/.match(text)
        if md
          string_isbn = md[1].strip
          book.isbn = string_isbn
        end
      end

      # another HACK of the same type as above
      unless book.saved_ident.instance_of? String

        md2 = /saved_ident: (.+)/.match(text)
        if md2
          string_saved_ident = md2[1].strip
          log.debug { "fixing saved_ident #{book.saved_ident} -> #{string_saved_ident}" }
          book.saved_ident = string_saved_ident
        end
      end
      if (book.isbn.instance_of? String) && book.isbn.empty?
        book.isbn = nil # save trouble later
      end
      book
    end
  end
end
