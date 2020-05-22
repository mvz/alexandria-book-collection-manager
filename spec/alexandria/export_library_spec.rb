# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

RSpec.describe Alexandria::ExportLibrary do
  let(:lib_version) { File.join(LIBDIR, "0.6.2") }

  let(:loader) { Alexandria::LibraryStore.new(TESTDIR) }

  let(:format) { Alexandria::ExportFormat.all.find { |it| it.message == message } }
  let(:outfile_base) { format.ext ? "my-library.#{format.ext}" : "my-library" }
  let(:outfile) { File.join(Dir.tmpdir, outfile_base) }

  let(:unsorted) { Alexandria::LibrarySortOrder::Unsorted.new }

  before do
    FileUtils.cp_r(lib_version, TESTDIR)
    @my_library = loader.load_library("My Library")
  end

  after do
    FileUtils.rm_rf(TESTDIR)
    FileUtils.rm_rf(outfile) if File.exist? outfile
  end

  describe "#export_as_csv_list" do
    let(:message) { :export_as_csv_list }

    def load_rows_from_csv
      CSV.read(outfile, col_sep: ";")
    end

    it "can sort by title" do
      sort_by_title = Alexandria::LibrarySortOrder.new(:title)
      format.invoke(@my_library, sort_by_title, outfile)
      expect(File.exist?(outfile)).to be_truthy
      rows = load_rows_from_csv
      rows.shift
      expect(@my_library.size).to eq 5
      expect(rows.size).to eq(@my_library.size)
      title_index = 0
      comparisons = rows.size - 1
      comparisons.times do |index|
        expect(rows[index][title_index]).to be <= rows[index + 1][title_index]
      end
    end

    it "can sort in descending order" do
      sort_by_date_desc = Alexandria::LibrarySortOrder.new(:publishing_year, false)
      format.invoke(@my_library, sort_by_date_desc, outfile)
      expect(File.exist?(outfile)).to be_truthy
      rows = load_rows_from_csv
      rows.shift
      expect(@my_library.size).to eq 5
      expect(rows.size).to eq(@my_library.size)
      date_index = 5
      comparisons = rows.size - 1
      comparisons.times do |index|
        expect(rows[index][date_index]).to be >= rows[index + 1][date_index]
      end
    end
  end

  describe "#export_as_html" do
    let(:message) { :export_as_html }
    let(:index) { File.join(outfile, "index.html") }

    it "can export unsorted" do
      format.invoke(@my_library, unsorted, outfile, Alexandria::WebTheme.all.first)
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
      format.invoke(@my_library, unsorted, outfile)
      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  describe "#export_as_tellico_xml_archive" do
    let(:message) { :export_as_tellico_xml_archive }

    it "can export unsorted" do
      format.invoke(@my_library, unsorted, outfile)
      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  describe "#export_as_bibtex" do
    let(:message) { :export_as_bibtex }

    it "can export unsorted" do
      format.invoke(@my_library, unsorted, outfile)
      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  describe "#export_as_isbn_list" do
    let(:message) { :export_as_isbn_list }

    it "can export unsorted" do
      format.invoke(@my_library, unsorted, outfile)
      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  describe "#export_as_ipod_notes" do
    let(:message) { :export_as_ipod_notes }
    let(:index) { File.join(outfile, "index.linx") }

    it "can export unsorted" do
      format.invoke(@my_library, unsorted, outfile, nil)
      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.size(index)).to be_nonzero
      end
    end
  end
end
