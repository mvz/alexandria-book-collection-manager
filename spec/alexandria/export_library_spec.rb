# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

RSpec.describe Alexandria::ExportLibrary do
  let(:my_library) do
    loader = Alexandria::LibraryStore.new(TESTDIR)
    loader.load_library("My Library")
  end
  let(:format) { Alexandria::ExportFormat.all.find { |it| it.message == message } }
  let(:outfile) do
    outfile_base = format.ext ? "my-library.#{format.ext}" : "my-library"
    File.join(Dir.tmpdir, outfile_base)
  end
  let(:unsorted) { Alexandria::LibrarySortOrder::Unsorted.new }

  before do
    test_library = File.join(LIBDIR, "0.6.2")
    FileUtils.cp_r(test_library, TESTDIR)
  end

  after do
    FileUtils.rm_rf(outfile)
  end

  describe "#export_as_csv_list" do
    let(:message) { :export_as_csv_list }

    def load_rows_from_csv
      CSV.read(outfile, col_sep: ";", headers: true)
    end

    it "can sort by title" do
      sort_by_title = Alexandria::LibrarySortOrder.new(:title)
      format.invoke(my_library, sort_by_title, outfile)
      rows = load_rows_from_csv
      titles = rows.map { |it| it["Title"] }
      expect(titles).to eq titles.sort
    end

    it "can sort in descending order" do
      sort_by_date_desc = Alexandria::LibrarySortOrder.new(:publishing_year, false)
      format.invoke(my_library, sort_by_date_desc, outfile)
      rows = load_rows_from_csv
      dates = rows.map { |it| it["Year Published"] }
      expect(dates).to eq dates.sort.reverse
    end
  end

  describe "#export_as_html" do
    let(:message) { :export_as_html }

    it "can export unsorted" do
      format.invoke(my_library, unsorted, outfile, Alexandria::WebTheme.all.first)
      index = File.join(outfile, "index.html")

      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.exist?(index)).to be_truthy
        expect(File.size(index)).to be_nonzero
      end
    end
  end

  describe "#export_as_onix_xml_archive" do
    let(:message) { :export_as_onix_xml_archive }

    it "can export unsorted" do
      format.invoke(my_library, unsorted, outfile)
      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  describe "#export_as_tellico_xml_archive" do
    let(:message) { :export_as_tellico_xml_archive }

    it "can export unsorted" do
      format.invoke(my_library, unsorted, outfile)
      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  describe "#export_as_bibtex" do
    let(:message) { :export_as_bibtex }

    it "can export unsorted" do
      format.invoke(my_library, unsorted, outfile)
      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  describe "#export_as_isbn_list" do
    let(:message) { :export_as_isbn_list }

    it "can export unsorted" do
      format.invoke(my_library, unsorted, outfile)
      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  describe "#export_as_ipod_notes" do
    let(:message) { :export_as_ipod_notes }

    it "can export unsorted" do
      format.invoke(my_library, unsorted, outfile, nil)
      index = File.join(outfile, "index.linx")

      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.size(index)).to be_nonzero
      end
    end
  end
end
