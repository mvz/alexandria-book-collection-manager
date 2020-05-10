# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "csv"
require "image_size"
require "tmpdir"

module Alexandria
  class ExportLibrary
    def initialize(library, sort_order)
      @library = library
      @sorted = sort_order.sort(library)
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

    def name
      @library.name
    end

    def each(&block)
      @sorted.each(&block)
    end

    def export_as_onix_xml_archive(filename)
      File.open(File.join(Dir.tmpdir, "onix.xml"), "w") do |io|
        to_onix_document.write(io, 0)
      end
      copy_covers(File.join(Dir.tmpdir, "images"))
      Dir.chdir(Dir.tmpdir) do
        output = `tar -cjf \"#{filename}\" onix.xml images 2>&1`
        raise output unless $CHILD_STATUS.success?
      end
      FileUtils.rm_rf(File.join(Dir.tmpdir, "images"))
      FileUtils.rm(File.join(Dir.tmpdir, "onix.xml"))
    end

    def export_as_tellico_xml_archive(filename)
      File.open(File.join(Dir.tmpdir, "tellico.xml"), "w") do |io|
        to_tellico_document.write(io, 0)
      rescue StandardError => ex
        puts ex.message
        puts ex.backtrace
        raise ex
      end
      copy_covers(File.join(Dir.tmpdir, "images"))
      Dir.chdir(Dir.tmpdir) do
        output = `zip -q -r \"#{filename}\" tellico.xml images 2>&1`
        raise output unless $CHILD_STATUS.success?
      end
      FileUtils.rm_rf(File.join(Dir.tmpdir, "images"))
      FileUtils.rm(File.join(Dir.tmpdir, "tellico.xml"))
    end

    def export_as_isbn_list(filename)
      File.open(filename, "w") do |io|
        each do |book|
          io.puts((book.isbn || ""))
        end
      end
    end

    def export_as_html(filename, theme)
      FileUtils.mkdir(filename) unless File.exist?(filename)
      Dir.chdir(filename) do
        copy_covers("pixmaps")
        FileUtils.cp_r(theme.pixmaps_directory, "pixmaps") if theme.has_pixmaps?
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

    def export_as_ipod_notes(filename, _theme)
      FileUtils.mkdir(filename) unless File.exist?(filename)
      tempdir = Dir.getwd
      Dir.chdir(filename)
      copy_covers("pixmaps")
      File.open("index.linx", "w") do |io|
        io.puts "<TITLE>" + name + "</TITLE>"
        each do |book|
          io.puts '<A HREF="' + book.ident + '">' + book.title + "</A>"
        end
        io.close
      end
      each do |book|
        File.open(book.ident, "w") do |io|
          io.puts "<TITLE>#{book.title} </TITLE>"
          # put a link to the book's cover. only works on iPod 5G and above(?).
          if File.exist?(cover(book))
            io.puts '<A HREF="pixmaps/' + book.ident + ".jpg" + '">' + book.title + "</A>"
          else
            io.puts book.title
          end
          io.puts book.authors.join(", ")
          io.puts book.edition
          io.puts((book.isbn || ""))
          # we need to close the files so the iPod can be ejected/unmounted
          # without us closing Alexandria
          io.close
        end
      end
      # Again, allow the iPod to unmount
      Dir.chdir(tempdir)
    end

    def export_as_csv_list(filename)
      CSV.open(filename, "w", col_sep: ";") do |csv|
        csv << ["Title", "Authors", "Publisher", "Edition", "ISBN", "Year Published",
                "Rating(#{Book::DEFAULT_RATING} to #{Book::MAX_RATING_STARS})", "Notes",
                "Want?", "Read?", "Own?", "Tags"]
        each do |book|
          csv << [book.title, book.authors.join(", "), book.publisher, book.edition,
                  book.isbn, book.publishing_year, book.rating, book.notes,
                  (book.want ? "1" : "0"), (book.redd ? "1" : "0"), (book.own ? "1" : "0"),
                  (book.tags ? book.tags.join(", ") : "")]
        end
      end
    end

    private

    ONIX_DTD_URL = "http://www.editeur.org/onix/2.1/reference/onix-international.dtd"
    def to_onix_document
      doc = REXML::Document.new
      doc << REXML::XMLDecl.new
      doc << REXML::DocType.new("ONIXMessage",
                                "SYSTEM \"#{ONIX_DTD_URL}\"")
      msg = doc.add_element("ONIXMessage")
      header = msg.add_element("Header")
      header.add_element("FromCompany").text = "Alexandria"
      header.add_element("FromPerson").text = Etc.getlogin
      now = Time.now
      header.add_element("SentDate").text = now.strftime("%Y%m%d%H%M")
      header.add_element("MessageNote").text = name
      @sorted.each_with_index do |book, idx|
        # fields that are missing: edition and rating.
        prod = msg.add_element("Product")
        prod.add_element("RecordReference").text = idx
        prod.add_element("NotificationType").text = "03"  # confirmed
        prod.add_element("RecordSourceName").text =
          "Alexandria " + Alexandria::DISPLAY_VERSION
        prod.add_element("ISBN").text = (book.isbn || "")
        prod.add_element("ProductForm").text = "BA"       # book
        prod.add_element("DistinctiveTitle").text = book.title
        unless book.authors.empty?
          book.authors.each do |author|
            elem = prod.add_element("Contributor")
            # author
            elem.add_element("ContributorRole").text = "A01"
            elem.add_element("PersonName").text = author
          end
        end
        if book.notes && !book.notes.empty?
          elem = prod.add_element("OtherText")
          # reader description
          elem.add_element("TextTypeCode").text = "12"
          elem.add_element("TextFormat").text = "00" # ASCII
          elem.add_element("Text").text = book.notes
        end
        if File.exist?(cover(book))
          elem = prod.add_element("MediaFile")
          # front cover image
          elem.add_element("MediaFileTypeCode").text = "04"
          elem.add_element("MediaFileFormatCode").text =
            (Library.jpeg?(cover(book)) ? "03" : "02")
          # filename
          elem.add_element("MediaFileLinkTypeCode").text = "06"
          elem.add_element("MediaFileLink").text =
            File.join("images", final_cover(book))
        end
        if book.isbn
          BookProviders.each do |provider|
            elem = prod.add_element("ProductWebsite")
            elem.add_element("ProductWebsiteDescription").text =
              provider.fullname
            elem.add_element("ProductWebsiteLink").text =
              provider.url(book)
          end
        end
        elem = prod.add_element("Publisher")
        elem.add_element("PublishingRole").text = "01"
        elem.add_element("PublisherName").text = book.publisher
        prod.add_element("PublicationDate").text = book.publishing_year
      end
      doc
    end

    def to_tellico_document
      # For the Tellico format, see
      # http://periapsis.org/tellico/doc/hacking.html
      doc = REXML::Document.new
      doc << REXML::XMLDecl.new
      doc << REXML::DocType.new("tellico",
                                'PUBLIC "-//Robby Stephenson/DTD Tellico V7.0//EN"' \
                                ' "http://periapsis.org/tellico/dtd/v7/tellico.dtd"')
      tellico = doc.add_element("tellico")
      tellico.add_attribute("syntaxVersion", "7")
      tellico.add_namespace("http://periapsis.org/tellico/")
      collection = tellico.add_element("collection")
      collection.add_attribute("title", name)
      collection.add_attribute("type", "2")
      fields = collection.add_element("fields")
      field1 = fields.add_element("field")
      # a field named _default implies adding all default book
      # collection fields
      field1.add_attribute("name", "_default")
      images = collection.add_element("images")
      @sorted.each_with_index do |book, idx|
        entry = collection.add_element("entry")
        new_index = (idx + 1).to_s
        entry.add_attribute("id", new_index)
        # translate the binding
        entry.add_element("title").text = book.title
        entry.add_element("isbn").text = (book.isbn || "")
        entry.add_element("pub_year").text = book.publishing_year
        entry.add_element("binding").text = book.edition
        entry.add_element("publisher").text = book.publisher
        unless book.authors.empty?
          authors = entry.add_element("authors")
          book.authors.each do |author|
            authors.add_element("author").text = author
          end
        end
        entry.add_element("read").text = book.redd.to_s if book.redd
        entry.add_element("loaned").text = book.loaned.to_s if book.loaned
        unless book.rating == Book::DEFAULT_RATING
          entry.add_element("rating").text = book.rating
        end
        entry.add_element("comments").text = book.notes if book.notes && !book.notes.empty?
        if File.exist?(cover(book))
          entry.add_element("cover").text = final_cover(book)
          image = images.add_element("image")
          image.add_attribute("id", final_cover(book))
          image_s = ImageSize.new(IO.read(cover(book)))
          image.add_attribute("height", image_s.height.to_s)
          image.add_attribute("width", image_s.width.to_s)
          image.add_attribute("format", image_s.format)
        end
      end
      doc
    end

    def xhtml_escape(str)
      escaped = str.dup
      # used to occasionally use CGI.escapeHTML
      escaped.gsub!(/&/, "&amp;")
      escaped.gsub!(/</, "&lt;")
      escaped.gsub!(/>/, "&gt;")
      escaped.gsub!(/\"/, "&quot;")
      escaped
    end

    def to_xhtml(css)
      generator = "Alexandria " + Alexandria::DISPLAY_VERSION
      xhtml = +""
      xhtml << <<~EOS
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
        xhtml << <<~EOS
          <div class="book">
            <p class="book_isbn">#{book.isbn}</p>
        EOS

        if File.exist?(cover(book))
          image_s = ImageSize.new(IO.read(cover(book)))
          xhtml << <<~EOS
            <img class="book_cover"
                 src="#{File.join('pixmaps', final_cover(book))}"
                 alt="Cover file for '#{xhtml_escape(book.title)}'"
                 height="#{image_s.height}" width="#{image_s.width}"
            />
          EOS
        else
          xhtml << <<~EOS
            <div class="no_book_cover"></div>
          EOS
        end

        unless book.title.nil?
          xhtml << <<~EOS
            <p class="book_title">#{xhtml_escape(book.title)}</p>
          EOS
        end

        unless book.authors.empty?
          xhtml << '<ul class="book_authors">'
          book.authors.each do |author|
            xhtml << <<~EOS
              <li class="book_author">#{xhtml_escape(author)}</li>
            EOS
          end
          xhtml << "</ul>"
        end

        unless book.edition.nil?
          xhtml << <<~EOS
            <p class="book_binding">#{xhtml_escape(book.edition)}</p>
          EOS
        end

        unless book.publisher.nil?
          xhtml << <<~EOS
            <p class="book_publisher">#{xhtml_escape(book.publisher)}</p>
          EOS
        end

        xhtml << <<~EOS
          </div>
        EOS
      end
      xhtml << <<~EOS
        <p class="copyright">
          Generated on #{xhtml_escape(Date.today.to_s)}
          by <a href="#{xhtml_escape(Alexandria::WEBSITE_URL)}">#{xhtml_escape(generator)}</a>.
        </p>
        </body>
        </html>
      EOS
    end

    def to_bibtex
      generator = "Alexandria " + Alexandria::DISPLAY_VERSION
      bibtex = +""
      bibtex << "\%Generated on #{Date.today} by: #{generator}\n"
      bibtex << "\%\n"
      bibtex << "\n"

      auths = Hash.new(0)
      each do |book|
        k = (book.authors[0] || "Anonymous").split[0]
        if auths.key?(k)
          auths[k] += 1
        else
          auths[k] = 1
        end
        cite_key = k + auths[k].to_s
        bibtex << "@BOOK{#{cite_key},\n"
        bibtex << 'author = "'
        if book.authors != []
          bibtex << book.authors[0]
          book.authors[1..-1].each do |author|
            bibtex << " and #{latex_escape(author)}"
          end
        end
        bibtex << "\",\n"
        bibtex << "title = \"#{latex_escape(book.title)}\",\n"
        bibtex << "publisher = \"#{latex_escape(book.publisher)}\",\n"
        if book.notes && !book.notes.empty?
          bibtex << "OPTnote = \"#{latex_escape(book.notes)}\",\n"
        end
        # year is a required field in bibtex @BOOK
        bibtex << "year = " + (book.publishing_year || '"n/a"').to_s + "\n"
        bibtex << "}\n\n"
      end
      bibtex
    end

    def latex_escape(str)
      return "" if str.nil?

      my_str = str.dup
      my_str.gsub!(/%/, '\\%')
      my_str.gsub!(/~/, '\\textasciitilde')
      my_str.gsub!(/\&/, '\\\\&')
      my_str.gsub!(/\#/, '\\\\#')
      my_str.gsub!(/\{/, '\\{')
      my_str.gsub!(/\}/, '\\}')
      my_str.gsub!(/_/, '\\_')
      my_str.gsub!(/\$/, "\\\$")
      my_str.gsub!(/\"(.+)\"/, "``\1''")
      my_str
    end
  end
end
