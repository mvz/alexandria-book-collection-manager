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

module Alexandria
    class ExportFormat
        attr_reader :name, :ext, :message

        include GetText
        extend GetText
        bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
        
        def self.all
        [
            self.new(_("Archived ONIX XML"), "onix.tbz2",
                     :export_as_onix_xml_archive),
            self.new(_("Archived Tellico XML"), "tc",
                     :export_as_tellico_xml_archive),
            self.new(_("ISBN List"), "txt", :export_as_isbn_list),
            self.new(_("HTML Web Page"), nil, :export_as_html, true)
        ]
        end

        def invoke(library, filename, *args)
            library.send(@message, filename, *args)
        end
       
        def needs_preview?
            @needs_preview
        end
       
        #######
        private
        #######
        
        def initialize(name, ext, message, needs_preview=false)
            @name = name
            @ext = ext
            @message = message
            @needs_preview = needs_preview
        end
    end

    class Library
        def export_as_onix_xml_archive(filename)
            File.open(File.join(Dir.tmpdir, "onix.xml"), "w") do |io|
                to_onix_document.write(io, 0)
            end
            copy_covers(File.join(Dir.tmpdir, "images"))
            Dir.chdir(Dir.tmpdir) do  
                output = `tar -cjf \"#{filename}\" onix.xml images 2>&1`
                raise output unless $?.success?
            end
            FileUtils.rm_rf(File.join(Dir.tmpdir, "images"))
            FileUtils.rm(File.join(Dir.tmpdir, "onix.xml"))
        end

        def export_as_tellico_xml_archive(filename)
            File.open(File.join(Dir.tmpdir, "tellico.xml"), "w") do |io|
                to_tellico_document.write(io, 0)
            end
            copy_covers(File.join(Dir.tmpdir, "images"))
            Dir.chdir(Dir.tmpdir) do
                output = `zip -q -r \"#{filename}\" tellico.xml images 2>&1`
                raise output unless $?.success?
            end
            FileUtils.rm_rf(File.join(Dir.tmpdir, "images"))
            FileUtils.rm(File.join(Dir.tmpdir, "tellico.xml"))
        end

        def export_as_isbn_list(filename)
            File.open(filename, 'w') do |io|
                each do |book|
                    io.puts book.isbn
                end
            end
        end
       
        def export_as_html(filename, theme)
            Dir.chdir(filename) do
                copy_covers("pixmaps")
                FileUtils.cp_r(theme.pixmaps_directory, 
                               "pixmaps") if theme.has_pixmaps?
                FileUtils.cp(theme.css_file, ".")
                File.open("index.html", "w") do |io|
                    io << to_xhtml(File.basename(theme.css_file))
                end
            end
        end
      
        #######  
        private
        #######

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
                    elem.add_element('MediaFileFormatCode').text = 
                        (jpeg?(cover(book)) ? '03' : '02' )
                    # filename
                    elem.add_element('MediaFileLinkTypeCode').text = '06'
                    elem.add_element('MediaFileLink').text = 
                        File.join('images', final_cover(book))
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
            bookcase.add_namespace('http://periapsis.org/bookcase/')
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
                    entry.add_element('cover').text = final_cover(book)
                    image = images.add_element('image')
                    image.add_attribute('id', final_cover(book))
                    image.add_attribute('format', jpeg?(cover(book)) \
                                                  ? "JPEG" : "GIF")
                end
            end
            return doc
        end
      
        def to_xhtml(css)
            generator = "Alexandria " + Alexandria::VERSION
            xhtml = ""
            xhtml << <<EOS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
                      "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  <meta name="generator" content="#{generator}"/>
  <title>#{name}</title>
  <link rel="stylesheet" href="#{css}" type="text/css"/>
</head>
<body>
<h1 class="library_name">#{name}</h1>
EOS
            each do |book|
                xhtml << <<EOS
<div class="book">
  <p class="book_isbn">#{book.isbn}</p>
EOS
                if File.exists?(cover(book))
                    xhtml << <<EOS
  <img class="book_cover"
       src="#{File.join("pixmaps", final_cover(book))}" 
       alt="Cover file for '#{book.title}'"/>
EOS
                else
                    xhtml << <<EOS
<div class="no_book_cover"></div>
EOS
                end
                xhtml << <<EOS
<p class="book_title">#{book.title}</p>
EOS
                unless book.authors.empty?
                    xhtml << "<ul class=\"book_authors\">"
                    book.authors.each do |author|
                        xhtml << <<EOS
<li class="book_author">#{author}</li>
EOS
                    end
                    xhtml << "</ul>"
                end
                xhtml << <<EOS
<p class="book_binding">#{book.edition}</p>
<p class="book_publisher">#{book.publisher}</p>
</div>
EOS
            end
            xhtml << <<EOS
<p class="copyright">
  Generated by <a href="#{Alexandria::WEBSITE_URL}">#{generator}</a>.
</p>
</body>
</html>
EOS
        end
    end
end
