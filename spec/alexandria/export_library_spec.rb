# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require 'spec_helper'

RSpec.describe Alexandria::ExportLibrary do
  let(:lib_version) { File.join(LIBDIR, '0.6.2') }
  let(:unsorted) { Alexandria::LibrarySortOrder::Unsorted.new }

  before do
    FileUtils.cp_r(lib_version, TESTDIR)
    @my_library = Alexandria::Library.loadall[0]
    expect(@my_library.size).to eq 5
  end

  describe '#export_as_csv_list' do
    let(:format) { Alexandria::ExportFormat.new('CSV list', 'csv', :export_as_csv_list) }
    let(:outfile) { File.join(Dir.tmpdir, 'my_library-0.6.2.csv') }

    def load_rows_from_csv
      CSV.read(outfile, col_sep: ';')
    end

    it 'can sort by title' do
      sort_by_title = Alexandria::LibrarySortOrder.new(:title)
      format.invoke(@my_library, sort_by_title, outfile)
      expect(File.exist?(outfile)).to be_truthy
      rows = load_rows_from_csv
      rows.shift
      expect(rows.size).to eq(@my_library.size)
      TITLE = 0
      comparisons = rows.size - 1
      comparisons.times do |index|
        expect(rows[index][TITLE]).to be <= rows[index + 1][TITLE]
      end
    end

    it 'can sort in descending order' do
      sort_by_date_desc = Alexandria::LibrarySortOrder.new(:publishing_year, false)
      format.invoke(@my_library, sort_by_date_desc, outfile)
      expect(File.exist?(outfile)).to be_truthy
      rows = load_rows_from_csv
      rows.shift
      expect(rows.size).to eq(@my_library.size)
      DATE = 5
      comparisons = rows.size - 1
      comparisons.times do |index|
        expect(rows[index][DATE]).to be >= rows[index + 1][DATE]
      end
    end
  end

  describe '#export_as_html' do
    let(:format) { Alexandria::ExportFormat.new('HTML Web Page', nil, :export_as_html, true) }
    let(:outfile) { File.join(Dir.tmpdir, 'my-library') }
    let(:index) { File.join(outfile, 'index.html') }

    it 'can export unsorted' do
      format.invoke(@my_library, unsorted, outfile, Alexandria::WebTheme.all.first)
      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.exist?(index)).to be_truthy
        expect(File.size(index)).to be_nonzero
      end
    end
  end

  describe '#export_as_onix_xml_archive' do
    let(:format) { Alexandria::ExportFormat.new('Archived ONIX XML', 'onix.tbz2', :export_as_onix_xml_archive) }
    let(:outfile) { File.join(Dir.tmpdir, 'my-library.oniz.tbz2') }

    it 'can export unsorted' do
      format.invoke(@my_library, unsorted, outfile)
      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  describe '#export_as_tellico_xml_archive' do
    let(:format) { Alexandria::ExportFormat.new('Archived Tellico XML', 'tc', :export_as_tellico_xml_archive) }
    let(:outfile) { File.join(Dir.tmpdir, 'my-library.tc') }

    it 'can export unsorted' do
      format.invoke(@my_library, unsorted, outfile)
      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  describe '#export_as_bibtex' do
    let(:message) { :export_as_bibtex }
    let(:format) { Alexandria::ExportFormat.all.find { |it| it.message == message } }
    let(:outfile) { File.join(Dir.tmpdir, "my-library.#{format.ext}") }

    it 'can export unsorted' do
      format.invoke(@my_library, unsorted, outfile)
      aggregate_failures do
        expect(File.exist?(outfile)).to be_truthy
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  after(:each) do
    FileUtils.rm_rf(TESTDIR)
    FileUtils.rm_rf(outfile) if File.exist? outfile
  end
end
