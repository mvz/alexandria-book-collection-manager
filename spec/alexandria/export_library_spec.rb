require 'spec_helper'

RSpec.describe Alexandria::ExportLibrary do
  context 'when exporting' do
    before(:all) do
      require 'tmpdir'
    end

    before(:each) do
      lib_version = File.join(LIBDIR, '0.6.2')
      FileUtils.cp_r(lib_version, TESTDIR)
      @format = Alexandria::ExportFormat.new('CSV list', 'csv', :export_as_csv_list)
      @outfile = File.join(Dir.tmpdir, 'my_library-0.6.2.csv')
      @my_library = Alexandria::Library.loadall[0]
    end

    def load_rows_from_csv
      CSV.read(@outfile, col_sep: ';')
    end

    it 'can sort by title' do
      sort_by_title = Alexandria::LibrarySortOrder.new(:title)
      @format.invoke(@my_library, sort_by_title, @outfile)
      expect(File.exist?(@outfile)).to be_truthy
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
      @format.invoke(@my_library, sort_by_date_desc, @outfile)
      expect(File.exist?(@outfile)).to be_truthy
      rows = load_rows_from_csv
      rows.shift
      expect(rows.size).to eq(@my_library.size)
      DATE = 5
      comparisons = rows.size - 1
      comparisons.times do |index|
        expect(rows[index][DATE]).to be >= rows[index + 1][DATE]
      end
    end

    after(:each) do
      FileUtils.rm_rf(TESTDIR)
      File.unlink @outfile if File.exist? @outfile
    end
  end
end

