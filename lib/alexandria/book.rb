require 'amazon/search'
require 'tempfile'
require 'open-uri'
require 'yaml'
require 'fileutils'
require 'singleton'

module Alexandria
    class Book
        attr_reader :title, :authors, :isbn, :publisher, :edition
        attr_accessor :rating, :notes

        DEFAULT_RATING = 3

        def initialize(title, authors, isbn, publisher, edition)
            @title = title
            @authors = authors
            @isbn = isbn
            @publisher = publisher
            @edition = edition
            @notes = ""
        end
    end

    class Library < Array
        attr_reader :name
        DIR = File.join(ENV['HOME'], '.alexandria')
        EXT = '.yaml'
        SMALL_COVER_EXT = '_small.jpg'
        MEDIUM_COVER_EXT = '_medium.jpg'

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
                    Dir["*" + EXT].each do |filename|
                        File.open(filename) do |io|
                            book = YAML.load(io)
                            raise "Not a book" unless book.is_a?(Book)
                            library << book
                        end
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
                a << self.load(_("My Library"))
            end
            a
        end

        def self.valid_isbn?(isbn)
            return false if isbn == nil

            digits = isbn.strip.delete('-').split('').map { |x|
                return false unless x =~ /[\dX]/
                x == 'X' ? 10 : x.to_i
            }

            if digits.length == 13
                # hope it's an EAN number
                digits = digits[3 .. 12]
            elsif digits.length != 10
                return false
            end

            (0 ... digits.length).inject(0) { |accumulator,i|
                accumulator + digits[i] * (i + 1)
            } % 11 == 0
        end

        def save(book, small_cover_uri=nil, medium_cover_uri=nil)
            if small_cover_uri and medium_cover_uri
                Dir.chdir(self.path) do
                    # Fetch the cover pictures.
                    File.open(small_cover(book), "w") do |io|
						io.puts URI.parse(small_cover_uri).read
					end
                    File.open(medium_cover(book), "w") do |io|
						io.puts URI.parse(medium_cover_uri).read
					end
                end
                self << book
            end
                
            File.open(File.join(self.path, book.isbn + EXT), "w") do |io|
                io.puts book.to_yaml
            end
        end

        alias_method :old_delete, :delete
        def delete(book=nil)
            if book.nil?
                # delete the whole library
                FileUtils.rm_rf(self.path)
            else
                File.delete(File.join(self.path, book.isbn + EXT),
                            small_cover(book), medium_cover(book))
                old_delete(book)
            end
        end

        def small_cover(book)
            File.join(self.path, book.isbn + SMALL_COVER_EXT)
        end
        
        def medium_cover(book)
            File.join(self.path, book.isbn + MEDIUM_COVER_EXT)
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
   
    class BookProviders < Array
        include Singleton
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
		SEARCH_BY_ISBN, SEARCH_BY_TITLE = 1, 2

    	def self.search(criterion, type)
            self.instance.each do |factory|
                begin
                    if stuff = factory.search(criterion, type)
                        return stuff
                    end
                rescue TimeoutError
                    raise _("Couldn't reach the provider '%s': timeout expired.") % factory.name
                end 
            end
    	end

		def self.isbn_search(criterion)
			self.search(criterion, SEARCH_BY_ISBN)
		end

		def self.title_search(criterion)
			self.search(criterion, SEARCH_BY_TITLE)
		end

        class Preferences < Array
            def initialize(provider_name)
                @provider_name = provider_name
            end

            class Variable
                attr_reader :provider_name, :name, :description, :possible_values
                attr_accessor :value
            
                def initialize(provider_name, name, description, default_value,
                               possible_values=nil)

                    @provider_name = provider_name
                    @name = name
                    @description = description
                    @value = default_value
                    @possible_values = possible_values
                end

                def new_value=(new_value)
                    Alexandria::Preferences.instance.send("#{provider_name}_#{name}=", new_value)
                    self.value = new_value
                end
            end
            
            def add(*args)
                self << Variable.new(@provider_name, *args) 
            end
            
            def [](obj)
                case obj
                    when String
                        var = self.find { |var| var.name == obj }
                        var ? var.value : nil
                    when Integer
                        old_idx(obj)
                end
            end
            alias_method :old_idx, :[]
            
            def read
                self.each do |var|
                    val = Alexandria::Preferences.instance.send("#{@provider_name}_#{var.name}")
                    var.value = val unless val.nil?
                end
            end
        end
        
        class AmazonProvider
            attr_reader :prefs, :name 
                
            include GetText
            GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
           
            def initialize
                @name = "Amazon"
                @prefs = Preferences.new(@name.downcase)
                @prefs.add("locale", _("Locale site to contact"), "us",
                           Amazon::Search::LOCALES.keys)
                @prefs.add("dev_token", _("Development token"), "D23XFCO2UKJY82")
                @prefs.add("associate", _("Associate ID"), "calibanorg-20")
            end
               
            def search(criterion, type)
                prefs.read
                
				req = Amazon::Search::Request.new(prefs["dev_token"])
                req.locale = prefs["locale"]
				
				products = []
				if type == Alexandria::BookProviders::SEARCH_BY_ISBN
					req.asin_search(criterion) { |product| products << product }
                	raise _("Too many results") if products.length > 1 # shouldn't happen
				else
					req.keyword_search(criterion) do |product|
						if /#{criterion}/i.match(product.product_name)
							products << product
						end
					end  
				end
 
				results = []
				products.each do |product|
                    next unless product.catalog == 'Book'
                    conv = proc { |str| GLib.convert(str, "ISO-8859-1", "UTF-8") }
                    book = Book.new(conv.call(product.product_name),
                                    (product.authors.map { |x| conv.call(x) } rescue [ "n/a" ]),
                                    conv.call(product.isbn),
                                    conv.call(product.manufacturer),
                                    conv.call(product.media))

                    results << [ book, product.image_url_small, product.image_url_medium ]
                end
				type == Alexandria::BookProviders::SEARCH_BY_ISBN ? results.first : results
            end
        end
       
        def initialize
            providers = [ AmazonProvider ].map { |x| x.new }
            super(providers.length, *providers)
        end

        def self.method_missing(id, *args, &block)
            self.instance.method(id).call(*args, &block)
        end
    end
end
