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

require 'open-uri'
require 'yaml'
require 'fileutils'
require 'gdk_pixbuf2'

module Alexandria
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
            
                    # Remove the files if they are blank.
                    [ small_cover(book), medium_cover(book) ].each do |file|
                        pixbuf = Gdk::Pixbuf.new(file)
                        if pixbuf.width == 1 and pixbuf.height == 1
                            File.delete(file)
                        end
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
end
