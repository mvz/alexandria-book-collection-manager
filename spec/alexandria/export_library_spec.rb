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
  let(:format) { Alexandria::ExportFormat.all.find { _1.message == message } }
  let(:outfile) do
    outfile_base = format.ext ? "my-library.#{format.ext}" : "my-library"
    File.join(Dir.mktmpdir, outfile_base)
  end

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
      titles = rows.map { _1["Title"] }
      expect(titles).to eq titles.sort
    end

    it "can sort in descending order" do
      sort_by_date_desc = Alexandria::LibrarySortOrder.new(:publishing_year, false)
      format.invoke(my_library, sort_by_date_desc, outfile)
      rows = load_rows_from_csv
      dates = rows.map { _1["Year Published"] }
      expect(dates).to eq dates.sort.reverse
    end
  end

  describe "#export_as_html" do
    let(:message) { :export_as_html }

    it "can export unsorted" do
      format.invoke(my_library, Alexandria::LibrarySortOrder::Unsorted.new,
                    outfile, Alexandria::WebTheme.all.first)
      index = File.join(outfile, "index.html")

      aggregate_failures do
        expect(outfile).to be_an_existing_file
        expect(index).to be_an_existing_file
        expect(File.size(index)).to be_nonzero
      end
    end
  end

  describe "#export_as_onix_xml_archive" do
    let(:message) { :export_as_onix_xml_archive }

    it "can export unsorted" do
      format.invoke(my_library, Alexandria::LibrarySortOrder::Unsorted.new, outfile)
      aggregate_failures do
        expect(outfile).to be_an_existing_file
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  describe "#export_as_tellico_xml_archive" do
    let(:message) { :export_as_tellico_xml_archive }

    it "can export unsorted" do
      format.invoke(my_library, Alexandria::LibrarySortOrder::Unsorted.new, outfile)
      aggregate_failures do
        expect(outfile).to be_an_existing_file
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  describe "#export_as_bibtex" do
    let(:message) { :export_as_bibtex }
    let(:expected_content) do
      <<~BIBTEX
        %Generated on #{Date.today} by: Alexandria #{Alexandria::DISPLAY_VERSION}
        %

        @BOOK{William1,
        author = "William Gibson",
        title = "Pattern Recognition",
        publisher = "Penguin Books Ltd",
        year = 2004
        }

        @BOOK{Francoise1,
        author = "Francoise Sagan and Irene Ash",
        title = "Bonjour Tristesse",
        publisher = "Penguin Books Ltd",
        OPTnote = "Essential penguin",
        year = 1998
        }

        @BOOK{Kazuo1,
        author = "Kazuo Ishiguro",
        title = "An Artist of the Floating World",
        publisher = "Faber and Faber",
        year = 1999
        }

        @BOOK{Ursula1,
        author = "Ursula Le Guin",
        title = "The Dispossessed",
        publisher = "Gollancz",
        OPTnote = "Gollancz S.F.",
        year = 2006
        }

        @BOOK{Neil1,
        author = "Neil Gaiman",
        title = "Neverwhere",
        publisher = "Headline Review",
        OPTnote = "The Author's Preferred Text",
        year = 2005
        }

      BIBTEX
    end

    it "can export unsorted" do
      format.invoke(my_library, Alexandria::LibrarySortOrder::Unsorted.new, outfile)
      aggregate_failures do
        expect(outfile).to be_an_existing_file
        expect(File.size(outfile)).to be_nonzero
        expect(File.read(outfile)).to eq expected_content
      end
    end
  end

  describe "#export_as_isbn_list" do
    let(:message) { :export_as_isbn_list }

    it "can export unsorted" do
      format.invoke(my_library, Alexandria::LibrarySortOrder::Unsorted.new, outfile)
      aggregate_failures do
        expect(outfile).to be_an_existing_file
        expect(File.size(outfile)).to be_nonzero
      end
    end
  end

  describe "#export_as_ipod_notes" do
    let(:message) { :export_as_ipod_notes }

    it "can export unsorted" do
      format.invoke(my_library, Alexandria::LibrarySortOrder::Unsorted.new, outfile, nil)
      index = File.join(outfile, "index.linx")

      aggregate_failures do
        expect(outfile).to be_an_existing_file
        expect(File.size(index)).to be_nonzero
      end
    end
  end
end
