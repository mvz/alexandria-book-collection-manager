require 'amazon/search'
require 'tempfile'
require 'net/http'
require 'uri'
require 'yaml'
require 'fileutils'

module Alexandria
    class Book
        attr_reader :title, :authors, :isbn, :publisher, :edition
        attr_accessor :small_cover, :medium_cover

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

        def saved=(state)
            @saved = state
        end
    end

    class BookList < Array
        attr_reader :name
        EXT = '.yaml'
       
        def path
            File.join(ENV['HOME'], '.alexandria', @name)
        end
        
        def self.load(name)
            list = BookList.new(name)
            begin
                Dir.chdir(list.path)
                Dir["*" + EXT].each do |filename|
                    File.open(filename) do |io|
                        book = YAML.load(io)
                        raise "Not a book" unless book.is_a?(Book)
                        list << book
                    end
                end
            rescue Errno::ENOENT
                FileUtils.mkdir_p(list.path)
            end
            list
        end
        
        def save
            Dir.chdir(self.path)
            self.each do |book|
                next if book.saved?
                File.open(File.join(self.path, book.isbn + EXT), "w") do |io|
                    small = File.join(self.path, book.isbn + "_small.jpg")
                    medium = File.join(self.path, book.isbn + "_medium.jpg")
                    FileUtils.mv(book.small_cover, small)
                    FileUtils.mv(book.medium_cover, medium)
                    book.small_cover = small
                    book.medium_cover = medium
                    book.saved = true
                    io.puts book.to_yaml
                end
            end
        end

        private
        def initialize(name)
            @name = name
        end
    end
    
    module BookProvider
    	def self.find(criteria, factory=nil)
    	    if factory
                book = factory.find(criteria)
            else
                self.each_factory do |factory|
                    break if book = factory.find(criteria)
                end
            end
            book or raise "Search failed"
    	end
    
    	def self.factories
    		self.constants.map { |x| self.module_eval(x) }.delete_if { |x| !x.is_a?(Module) }
    	end
    
        def self.each_factory
            self.factories.each { |factory| yield factory }
            nil
        end
            
    	module AmazonProvider
    		def self.find(criteria)
                results = []
                req = Amazon::Search::Request.new('foo')
                req.asin_search(criteria) do |product|
                    next unless product.catalog == 'Book'
                    fetch = lambda do |url|
                        io = Tempfile.open(product.isbn)
                        io.puts(Net::HTTP.get(URI.parse(url)))
                        io.close
                        io.path
                    end
                    book = Book.new(product.productname,
                                    product.authors,
                                    product.isbn,
                                    product.manufacturer,
                                    product.media,
                                    fetch.call(product.imageurlsmall),
                                    fetch.call(product.imageurlmedium))
                    results << book
                end
                raise "Too many results" unless results.length == 1
                results.first
    		end
    	end
    end

end
