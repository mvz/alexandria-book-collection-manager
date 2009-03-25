# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2007 Cathal Mc Ginley
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

# Export sorting added 23 Oct 2007 by Cathal Mc Ginley
# Classes LibrarySortOrder and SortedLibrary, and changed ExportFormat#invoke
# iPod Notes support added 20 January 2008 by Tim Malone
#require 'cgi'

begin        # image_size is optional
  $IMAGE_SIZE_LOADED = true
  require 'image_size'
rescue LoadError
  $IMAGE_SIZE_LOADED = false
  puts "Can't load image_size, hence exported libraries are not optimized" if $DEBUG
end

module Alexandria

  class LibrarySortOrder
    include Logging

    def initialize(book_attribute, ascending=true)
      @book_attribute = book_attribute
      @ascending = ascending
    end

    def sort(library)
      begin
        sorted = library.sort_by do |book|
          book.send(@book_attribute)
        end
        if not @ascending
          sorted.reverse!
        end
        sorted
      rescue Exception => ex
        trace = ex.backtrace.join("\n> ")
        log.warn { "Could not sort library by #{@book_attribute} #{ex.message} #{trace}" }
        library
      end
    end

    def to_s
      "#{@book_attribute} #{@ascending ? '(ascending)' : '(descending)'}"
    end

    class Unsorted < LibrarySortOrder
      def initialize
      end

      def sort(library)
        library
      end

      def to_s
        "default order"
      end
    end
  end

  class SortedLibrary < Library
    def initialize(library, sort_order)
      super(library.name)
      @library = library
      sorted = sort_order.sort(library)
      sorted.each do |book|
        self << book
      end
    end

    def cover(book)
      @library.cover(book)
    end

    def final_cover(book)
      @library.final_cover(book)
    end

    def copy_covers(dest)
      @library.copy_covers(dest)
    end
  end

  class ExportFormat
    attr_reader :name, :ext, :message

    include GetText
    include Logging
    extend GetText
    bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

    def self.all
      [
        self.new(_("Archived ONIX XML"), "onix.tbz2",
                 :export_as_onix_xml_archive),
                 self.new(_("Archived Tellico XML"), "tc",
                          :export_as_tellico_xml_archive),
                          self.new(_("BibTeX"), "bib", :export_as_bibtex),
                          self.new(_("CSV list"), "csv", :export_as_csv_list),
                          self.new(_("ISBN List"), "txt", :export_as_isbn_list),
                          self.new(_("iPod Notes"), nil, :export_as_ipod_notes),
                          self.new(_("HTML Web Page"), nil, :export_as_html, true)
      ]
    end

    def invoke(library, sort_order, filename, *args)
      if sort_order
        sorted = SortedLibrary.new(library, sort_order)
        log.debug { "Exporting library sorted by #{sort_order}" }
        sorted.send(@message, filename, *args)
      else
        library.send(@message, filename, *args)
      end
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

  module Exportable
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
        begin
          to_tellico_document.write(io, 0)
        rescue Exception => ex
          puts ex.message
          puts ex.backtrace
          raise ex
        end
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
          io.puts((book.isbn or ""))
        end
      end
    end

    def export_as_html(filename, theme)
      FileUtils.mkdir(filename) unless File.exists?(filename)
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

    def export_as_bibtex(filename)
      File.open(filename, "w") do |io|
        io << to_bibtex
      end
    end
    def export_as_ipod_notes(filename, theme)
      FileUtils.mkdir(filename) unless File.exists?(filename)
      tempdir=Dir.getwd                
      Dir.chdir(filename)
      copy_covers("pixmaps")
      File.open("index.linx", 'w') do |io|
        io.puts '<TITLE>' + name + '</TITLE>'
        each do |book|
          io.puts '<A HREF="' + book.ident + '">' + book.title + '</A>'
        end
        io.close
      end
      each do |book|
        File.open(book.ident, 'w') do |io|
          io.puts "<TITLE>#{book.title} </TITLE>"
          #put a link to the book's cover. only works on iPod 5G and above(?).
          if File.exists?(cover(book))
            io.puts '<A HREF="pixmaps/' + book.ident + '.jpg' + '">' + book.title + '</A>'
          else
            io.puts book.title
          end
          io.puts book.authors.join(', ')
          io.puts book.edition
          io.puts((book.isbn or ""))
          #we need to close the files so the iPod can be ejected/unmounted without us closing Alexandria				
          io.close
        end

      end
      #Again, allow the iPod to unmount		
      Dir.chdir(tempdir)
    end


    def export_as_csv_list(filename)
      File.open(filename, 'w') do |io|
        io.puts "Title" + ';' + "Authors" + ';' + "Publisher" + ';' + "Edition" + ';' + "ISBN" + ';' + "Year Published" + ';' + "Rating" + "(0 to #{UI::MainApp::MAX_RATING_STARS.to_s})" + ';' + "Notes" + ';' + "Want?" + ';' + "Read?" + ';' + "Own?" + ';' + "Tags"
        each do |book|
          io.puts book.title + ';' + book.authors.join(', ') + ';' + (book.publisher or "") + ';' + (book.edition or "") + ';' + (book.isbn or "") + ';' + (book.publishing_year.to_s or "") + ';' + (book.rating.to_s or "0") + ';' + (book.notes or "") + ';' + ( book.want ? "1" : "0") + ';' + ( book.redd ? "1" : "0") + ';' + ( book.own ? "1" : "0") + ';' + (book.tags ? book.tags.join(', ') : "")
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
      header.add_element('FromCompany').text = "Alexandria"
      header.add_element('FromPerson').text = Etc.getlogin
      now = Time.now
      header.add_element('SentDate').text = "%.4d%.2d%.2d%.2d%.2d" % [
        now.year, now.month, now.day, now.hour, now.min
      ]
      header.add_element('MessageNote').text = name
      each_with_index do |book, idx|
        # fields that are missing: edition and rating.
        prod = msg.add_element('Product')
        prod.add_element('RecordReference').text = idx
        prod.add_element('NotificationType').text = "03"  # confirmed
        prod.add_element('RecordSourceName').text =
          "Alexandria " + Alexandria::DISPLAY_VERSION
        prod.add_element('ISBN').text = (book.isbn or "")
        prod.add_element('ProductForm').text = 'BA'       # book
        prod.add_element('DistinctiveTitle').text = book.title
        unless book.authors.empty?
          book.authors.each do |author|
            elem = prod.add_element('Contributor')
            # author
            elem.add_element('ContributorRole').text = 'A01'
            elem.add_element('PersonName').text = author
          end
        end
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
          (Library.jpeg?(cover(book)) ? '03' : '02' )
          # filename
          elem.add_element('MediaFileLinkTypeCode').text = '06'
          elem.add_element('MediaFileLink').text =
          File.join('images', final_cover(book))
        end
        if book.isbn
          BookProviders.each do |provider|
            elem = prod.add_element('ProductWebsite')
            elem.add_element('ProductWebsiteDescription').text =
              provider.fullname
            elem.add_element('ProductWebsiteLink').text =
              provider.url(book)
          end
        end
        elem = prod.add_element('Publisher')
        elem.add_element('PublishingRole').text = '01'
        elem.add_element('PublisherName').text = book.publisher
        prod.add_element('PublicationDate').text = book.publishing_year
      end
      return doc
    end

    def to_tellico_document
      # For the Tellico format, see
      # http://periapsis.org/tellico/doc/hacking.html
      doc = REXML::Document.new
      doc << REXML::XMLDecl.new
      doc << REXML::DocType.new('tellico', "PUBLIC \"-//Robby Stephenson/DTD Tellico V7.0//EN\" \"http://periapsis.org/tellico/dtd/v7/tellico.dtd\"")
      tellico = doc.add_element('tellico')
      tellico.add_attribute('syntaxVersion', "7")
      tellico.add_namespace('http://periapsis.org/tellico/')
      collection = tellico.add_element('collection')
      collection.add_attribute('title', self.name)
      collection.add_attribute('type', "2")
      fields = collection.add_element('fields')
      field1 = fields.add_element('field')
      # a field named _default implies adding all default book
      # collection fields
      field1.add_attribute('name', "_default")
      images = collection.add_element('images')
      each_with_index do |book, idx|
        entry = collection.add_element('entry')
        new_index = (idx+1).to_s
        entry.add_attribute('id', new_index)
        # translate the binding
        entry.add_element('title').text = book.title
        entry.add_element('isbn').text = (book.isbn or "")
        entry.add_element('pub_year').text = book.publishing_year
        entry.add_element('binding').text = book.edition
        entry.add_element('publisher').text = book.publisher
        unless book.authors.empty?
          authors = entry.add_element('authors')
          book.authors.each do |author|
            authors.add_element('author').text = author
          end
        end
        entry.add_element('read').text = book.redd.to_s if book.redd
        entry.add_element('loaned').text = book.loaned.to_s if book.loaned
        if not book.rating == Book::DEFAULT_RATING
          entry.add_element('rating').text = book.rating
        end
        if book.notes and not book.notes.empty?
          entry.add_element('comments').text = book.notes
        end
        if File.exists?(cover(book))
          entry.add_element('cover').text = final_cover(book)
          image = images.add_element('image')
          image.add_attribute('id', final_cover(book))
          if $IMAGE_SIZE_LOADED
            image_s = ImageSize.new(IO.read(cover(book)))
            image.add_attribute('height', image_s.get_height.to_s)
            image.add_attribute('width', image_s.get_width.to_s)
            image.add_attribute('format', image_s.get_type)
          else
            image.add_attribute('format',
                                Library.jpeg?(cover(book)) \
                                ? "JPEG" : "GIF")
          end
        end
      end
      return doc
    end

    def xhtml_escape(str)
      escaped = str.dup
      # used to occasionally use CGI.escapeHTML
      escaped.gsub!(/&/, '&amp;')
      escaped.gsub!(/</, '&lt;')
      escaped.gsub!(/>/, '&gt;')
      escaped.gsub!(/\"/, '&quot;')
      escaped
    end

    def to_xhtml(css)
      generator = "Alexandria " + Alexandria::DISPLAY_VERSION
      xhtml = ""
      xhtml << <<EOS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
                      "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
  <meta name="Author" content="#{Etc.getlogin}"/>
  <meta name="Description" content="List of books"/>
  <meta name="Keywords" content="books"/>
  <meta name="Generator" content="#{xhtml_escape(generator)}"/>
  <title>#{xhtml_escape(name)}</title>
  <link rel="stylesheet" href="#{xhtml_escape(css)}" type="text/css"/>
</head>
<body>
<h1 class="library_name">#{xhtml_escape(name)}</h1>
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
       alt="Cover file for '#{xhtml_escape(book.title)}'"
EOS
          if $IMAGE_SIZE_LOADED
            image_s = ImageSize.new(IO.read(cover(book)))
            xhtml << <<EOS
       height="#{image_s.get_height}" width="#{image_s.get_width}"
EOS
          end
          xhtml << <<EOS
  />
EOS
        else
          xhtml << <<EOS
<div class="no_book_cover"></div>
EOS
        end

        unless book.title == nil
          xhtml << <<EOS
<p class="book_title">#{xhtml_escape(book.title)}</p>
EOS
        end

        unless book.authors.empty?
          xhtml << "<ul class=\"book_authors\">"
          book.authors.each do |author|
            xhtml << <<EOS
<li class="book_author">#{xhtml_escape(author)}</li>
EOS
          end
          xhtml << "</ul>"
        end

        unless book.edition == nil
          xhtml << <<EOS
<p class="book_binding">#{xhtml_escape(book.edition)}</p>
EOS
        end

        unless book.publisher == nil
          xhtml << <<EOS
<p class="book_publisher">#{xhtml_escape(book.publisher)}</p>
EOS
        end

        xhtml << <<EOS
</div>
EOS
      end
      xhtml << <<EOS
<p class="copyright">
  Generated on #{xhtml_escape(Date.today().to_s)} by <a href="#{xhtml_escape(Alexandria::WEBSITE_URL)}">#{xhtml_escape(generator)}</a>.
</p>
</body>
</html>
EOS
    end

    def to_bibtex
      generator = "Alexandria " + Alexandria::DISPLAY_VERSION
      bibtex = ""
      bibtex << "\%Generated on #{Date.today()} by: #{generator}\n"
      bibtex << "\%\n"
      bibtex << "\n"

      auths = Hash.new(0)
      each do |book|
        k = (book.authors[0] or "Anonymous").split[0]
        if auths.has_key?(k)
          auths[k] += 1
        else
          auths[k] = 1
        end
        cite_key = k + auths[k].to_s
        bibtex << "@BOOK{#{cite_key},\n"
        bibtex << "author = \""
        if book.authors != []
          bibtex << book.authors[0]
          book.authors[1..-1].each do |author|
            bibtex << " and #{latex_escape(author)}"
          end
        end
        bibtex << "\",\n"
        bibtex << "title = \"#{latex_escape(book.title)}\",\n"
        bibtex << "publisher = \"#{latex_escape(book.publisher)}\",\n"
        if book.notes and not book.notes.empty?
          bibtex << "OPTnote = \"#{latex_escape(book.notes)}\",\n"
        end
        #year is a required field in bibtex @BOOK
        bibtex << "year = " + (book.publishing_year or "\"n/a\"").to_s + "\n"
        bibtex << "}\n\n"
      end
      return bibtex
    end

    def latex_escape(str)
      return "" if str == nil
      my_str = str.dup
      my_str.gsub!(/%/,"\\%")
      my_str.gsub!(/~/,"\\textasciitilde")
      my_str.gsub!(/\&/,"\\\\&")
      my_str.gsub!(/\#/,"\\\\#")
        my_str.gsub!(/\{/,"\\{")
          my_str.gsub!(/\}/,"\\}")
          my_str.gsub!(/_/,"\\_")
          my_str.gsub!(/\$/,"\\\$")
          my_str.gsub!(/\"(.+)\"/, %q/``\1''/)
          return my_str
    end
  end

  class Library
    include Exportable
  end

  class SmartLibrary
    include Exportable
  end
end
