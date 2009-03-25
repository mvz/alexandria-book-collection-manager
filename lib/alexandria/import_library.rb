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
require 'gettext'

module Alexandria
  class ImportFilter
    attr_reader :name, :patterns, :message

    include GetText
    extend GetText
    bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

    def self.all
      [
       self.new(_("Autodetect"), ['*'], :import_autodetect),
       self.new(_("Archived Tellico XML (*.bc, *.tc)"),
                ['*.tc', '*.bc'], :import_as_tellico_xml_archive),
       self.new(_("ISBN List (*.txt)"), ['*.txt'],
                :import_as_isbn_list),
	self.new(_("GoodReads CSV"), ['*.csv'],
		:import_as_csv_file)
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
          puts e.backtrace.join("\n>> ")
        end
      elsif [".csv"].include? filename[-4..-1]
	self.import_as_csv_file(*args)
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

            book_elements = [neaten(elements['title'].text)]
            if elements['authors'] != nil
              book_elements += [elements['authors'].elements.to_a.map \
                                { |x| neaten(x.text) }]
            else
              book_elements += [[]]
            end
            book_elements += keys.map {|key|
              unless elements[key]
                nil
              else
                neaten(elements[key].text)
              end
            }
            #isbn
            if book_elements[2].nil? or book_elements[2].strip.empty?
              book_elements[2] = nil
            else              
              begin
                book_elements[2] = book_elements[2].strip
                book_elements[2] = Library.canonicalise_ean(book_elements[2])
              rescue Exception => ex
                puts book_elements[2]
                puts ex.message
                puts ex.backtrace.join("\n> ")
                raise ex
              end
            end
            book_elements[4] = book_elements[4].to_i unless book_elements[4]== nil # publishing_year
            puts book_elements.inspect
            if elements['cover']
              cover = neaten(elements['cover'].text)
            else
              cover = nil
            end
            puts cover
            book = Book.new(*book_elements)
            if elements['rating'] and (0..UI::MainApp::MAX_RATING_STARS).map.member? elements['rating'].text.to_i
              book.rating = elements['rating'].text.to_i
            end
            book.notes = neaten(elements['comments'].text) if elements['comments']
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

def self.import_as_csv_file(name, filename, on_iterate_cb,
                                 on_error_cb)
	require 'csv'
	books = []
	current_iteration=1

	puts "Starting import_as_csv_file..."
        csv_file =IO.readlines(filename).map
	max_iterations=csv_file.length
	puts max_iterations        
	#check to make sure we can deal with this file.
	#GoodReads doesn't provide a header of any sort to this file.
	temp_line=CSV::parse_line(csv_file[0], ',')
	if temp_line[2].include? "ISBN"
		#if the ISBN is in column three, we can at least import as an ISBN list.		
		puts "Looks good so far, lets give it a go" if $DEBUG
	else
		puts "not a goodreads file?" if $DEBUG
		return
	end
	#the first line just contains the headers, get rid of it.
	csv_file.shift	
	begin	
	csv_file.each do |line|
		book_temp = []
		@cover_temp = nil		
		element = CSV::parse_line((line.delete '='), ',') 
		
		#why does it add strange CSV information when we don't just create a new string? Same thing happens with Amazon lookups I noticed.			
		element[0]=String.new("unknown") if element[0]==nil
		element[1]=String.new("unknown") if element[1]==nil
		element[5]=String.new("unknown") if element[5]==nil
		#we have to have a publishing year
		element[7]=0000 if element[7] == nil
		element[6]=String.new("unknown") if element[6]==nil
		authors = [] #GoodReads only seems to support 1 author. Maybe add support for multiple authors if this gets expanded to a generic csv importer.
		authors << String.new(element[1])
		#element 2 is the ISBN.		
		if element[2] != nil
			puts element[2] if $DEBUG
			Library.canonicalise_ean(element[2]) unless element[2]== nil # isbn			
			#we have to search online for the cover image anyway, so we may as well get the most up to date data			
			book_temp, @cover_temp = Alexandria::BookProviders.isbn_search(element[2])
		else	
			#if the book doesn't have an ISBN we'll just add the book manually.
			puts "no ISBN"	if $DEBUG			
			book_temp=Book.new(String.new(element[0]),authors,nil,String.new(element[5]),element[7].to_i,String.new(element[6]))
		end
		#some providers (the Belium provider for instance) seem to give bad binding information, so use the goodreads data if availalbe.
		book_temp.edition=String.new(element[6]) unless element[6] == nil
		#the fourth column of the file is the rating the user gave to the book, we should preserve that.						
		if element[3] != nil			
			begin
			book_temp.rating=element[3].to_i
			rescue
			puts "Can't convert rating"
			book_temp.rating=0
			end
		end
		#preserve the date the user read the book
		if element[9] != nil
			book_temp.redd=true
			begin
			book_temp.redd_when=Time.parse(element[9])
			rescue
			puts "Couldn't parse Date Read, putting nil date"
			end
		end
		#Save the bookshelves as tags
		if element[11] != nil			
			book_temp.tags=(String.new(element[11])).split(' ')
		end
		#also preserve any notes.			
		if element[12] != nil
			book_temp.notes=String.new(element[12])
		end
		books << [book_temp, @cover_temp]
		on_iterate_cb.call(current_iteration += 1,
                           max_iterations) if on_iterate_cb
	end
	library = Library.load(name)
      	puts "Going with these #{books.length} books: #{books.inspect}" if $DEBUG
      	books.each do |book, cover_uri|
        	puts "Saving #{book.isbn} cover..." if $DEBUG
        	library.save_cover(book, cover_uri) if cover_uri != nil
        	puts "Saving #{book.isbn}..." if $DEBUG
        	library << book
        	library.save(book)
	end
	rescue => e
		puts e.message		
		return nil
	end
	return [library, []]
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

    private

    def self.neaten(str)
      if str
        str.strip
      else
        str
      end
    end

  end
end
