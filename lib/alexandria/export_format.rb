# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  class ExportFormat
    attr_reader :name, :ext, :message

    include GetText
    include Logging
    extend GetText
    bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

    def self.all
      [
        new(_("Archived ONIX XML"), "onix.tbz2", :export_as_onix_xml_archive),
        new(_("Archived Tellico XML"), "tc", :export_as_tellico_xml_archive),
        new(_("BibTeX"), "bib", :export_as_bibtex),
        new(_("CSV list"), "csv", :export_as_csv_list),
        new(_("ISBN List"), "txt", :export_as_isbn_list),
        new(_("iPod Notes"), nil, :export_as_ipod_notes),
        new(_("HTML Web Page"), nil, :export_as_html, true)
      ]
    end

    def invoke(library, sort_order, filename, *args)
      sorted = ExportLibrary.new(library, sort_order)
      log.debug { "Exporting library sorted by #{sort_order}" }
      sorted.send(@message, filename, *args)
    end

    def needs_preview?
      @needs_preview
    end

    private

    def initialize(name, ext, message, needs_preview = false)
      @name = name
      @ext = ext
      @message = message
      @needs_preview = needs_preview
    end
  end
end
