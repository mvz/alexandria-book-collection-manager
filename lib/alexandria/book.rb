require 'amazon/search'
require 'tempfile'
require 'net/http'
require 'uri'
require 'yaml'
require 'fileutils'
require 'singleton'

module Alexandria
    class Book
        attr_reader :title, :authors, :isbn, :publisher, :edition
        attr_writer :saved, :small_cover, :medium_cover
        attr_accessor :library

        def initialize(title, authors, isbn, publisher, edition,
                       small_cover, medium_cover)

            @title = title
            @authors = authors
            @isbn = isbn
            @publisher = publisher
            @edition = edition
            @small_cover = small_cover
            @medium_cover = medium_cover
            @saved = false
        end

        def saved?
            @saved
        end

        def small_cover
            @library ? File.join(@library.path, @small_cover) : @small_cover
        end
        
        def medium_cover
            @library ? File.join(@library.path, @medium_cover) : @medium_cover
        end
    end

    class Library < Array
        attr_reader :name
        DIR = File.join(ENV['HOME'], '.alexandria')
        EXT = '.yaml'
        SMALL_COVER_EXT = '_small.jpg'
        MEDIUM_COVER_EXT = '_medium.jpg'

        def path
            File.join(DIR, @name)
        end

        def self.load(name)
            library = Library.new(name)
            begin
                Dir.chdir(library.path)
                Dir["*" + EXT].each do |filename|
                    File.open(filename) do |io|
                        book = YAML.load(io)
                        raise "Not a book" unless book.is_a?(Book)
                        book.library = library
                        library << book
                    end
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
                a << self.load("My Library")
            end
            a
        end
 
        def save
            Dir.chdir(self.path)
            self.each do |book|
                next if book.saved?
                File.open(File.join(self.path, book.isbn + EXT), "w") do |io|
                    small = File.join(self.path, book.isbn + SMALL_COVER_EXT)
                    medium = File.join(self.path, book.isbn + MEDIUM_COVER_EXT)
                    FileUtils.mv(book.small_cover, small)
                    FileUtils.mv(book.medium_cover, medium)
                    book.small_cover = File.basename(small)
                    book.medium_cover = File.basename(medium)
                    book.saved = true
                    io.puts book.to_yaml
                end
            end
        end

        alias_method :old_delete, :delete
        def delete(book=nil)
            if book.nil?
                # delete the whole library
                FileUtils.rm_rf(self.path)
            else
                File.delete(File.join(self.path, book.isbn + EXT),
                            File.join(self.path, book.isbn + SMALL_COVER_EXT),
                            File.join(self.path, book.isbn + MEDIUM_COVER_EXT))
                old_delete(book)
            end
        end

        def name=(name)
            File.rename(path, File.join(DIR, name))
            @name = name
        end

        #######
        private
        #######

        def initialize(name)
            @name = name
        end
    end
   
    class BookProvider
        include Singleton

    	def self.find(criteria, factory=nil)
            book = nil
            begin
                if factory.nil?
                    PROVIDERS.each do |factory|
                        if book = factory.instance.find(criteria)
                            break
                        end
                    end
                else
                    book = factory.instance.find(criteria)
                end
            rescue TimeoutError
                raise "Couldn't reach the provider '#{factory.instance.name}': timeout expired."
            end 
            return book
    	end

        class ConfVariable
            attr_reader :name, :description, :possible_values
            attr_accessor :value

            def initialize(name, description, possible_values, default_value)
                @name = name
                @description = description
                @possible_values = possible_values
                @value = default_value
            end
        end
        
        class AmazonProvider < self
            attr_reader :prefs, :name

            def initialize
                @name = "Amazon"
                @prefs = {
                    :locale    => ConfVariable.new("locale",
                                                   "Locale site to contact.",
                                                   Amazon::Search::LOCALES.keys,
                                                   "us"),
                    :dev_token => ConfVariable.new("dev_token",
                                                   "Development token.",
                                                   nil, "0xDEADBEEF")
                }
            end
                
        	def find(criteria)
                results = []
                req = Amazon::Search::Request.new(prefs[:dev_token].value)
                req.locale = prefs[:locale].value
                req.asin_search(criteria) do |product|
                    next unless product.catalog == 'Book'
                    fetch = lambda do |url|
                        io = Tempfile.open(product.isbn)
                        io.puts(Net::HTTP.get(URI.parse(url)))
                        io.close
                        io.path
                    end
                    book = Book.new(product.product_name,
                                    (product.authors rescue [ "n/a" ]),
                                    product.isbn,
                                    product.manufacturer,
                                    product.media,
                                    fetch.call(product.image_url_small),
                                    fetch.call(product.image_url_medium))
                    results << book
                end
                raise "Too many results" unless results.length == 1
                results.first
        	end
        end
        
        PROVIDERS = [ AmazonProvider ]

        def self.all
            PROVIDERS
        end

        def self.each
            PROVIDERS.each { |x| yield x } if block_given?
        end
    end
end
