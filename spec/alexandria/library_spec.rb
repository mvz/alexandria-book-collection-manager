# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

describe Alexandria::Library do
  let(:loader) { Alexandria::LibraryStore.new(TESTDIR) }

  describe "::EXT" do
    it "has symbolic references to file extensions" do
      extensions = Alexandria::Library::EXT
      expect(extensions[:book]).not_to be_nil
      expect(extensions[:cover]).not_to be_nil
    end
  end

  describe "#valid_isbn?" do
    it "returns a true value for valid isbns" do
      ["014143984X", "0-345-43192-8"].each do |x|
        expect(described_class.valid_isbn?(x)).to be_truthy
      end
    end
  end

  describe "#valid_ean?" do
    it "returns a true value for valid EANs" do
      expect(described_class.valid_ean?("9780345431929")).to be_truthy
      expect(described_class.valid_ean?("978034543192912345")).to be_truthy

      # Regression test: this EAN has a checksum of 10, which should be
      # treated like a checksum of 0.
      expect(described_class.valid_ean?("9784047041790")).to be_truthy
    end

    it "returns a false value for invalid EANs" do
      expect(described_class.valid_ean?("780345431929")).to be_falsey
      expect(described_class.valid_ean?("97803454319290")).to be_falsey
      expect(described_class.valid_ean?("97803454319291234")).to be_falsey
      expect(described_class.valid_ean?("9780345431929123456")).to be_falsey
      expect(described_class.valid_ean?("9780345431928")).to be_falsey
      expect(described_class.valid_ean?("9780345431929A")).to be_falsey

      expect(described_class.valid_ean?("9784047041791")).to be_falsey
    end
  end

  describe "#valid_upc?" do
    it "returns a true value for valid UPCs" do
      expect(described_class.valid_upc?("97803454319312356")).to be_truthy
    end

    it "returns a false value for invalid UPCs" do
      expect(described_class.valid_upc?("978034543193123567")).to be_falsey
      expect(described_class.valid_upc?("9780345431931235")).to be_falsey

      expect(described_class.valid_upc?("97803454319412356")).to be_falsey
      expect(described_class.valid_upc?("97803454319212356")).to be_falsey
    end
  end

  describe "#canonicalise_isbn" do
    it "returns the correct value for several examples" do
      expect(described_class.canonicalise_isbn("014143984X")).to eq "014143984X"
      expect(described_class.canonicalise_isbn("0-345-43192-8")).to eq "0345431928"
      expect(described_class.canonicalise_isbn("3522105907")).to eq "3522105907"
      # EAN number
      expect(described_class.canonicalise_isbn("9780345431929")).to eq "0345431928"
    end
  end

  context "with an empty library" do
    let(:my_library) { loader.load_library("Empty") }

    before do
      FileUtils.mkdir(TESTDIR) unless File.exist? TESTDIR
    end

    it "disallows multiple deletion of the same copy of a book" do
      first_copy = an_artist_of_the_floating_world
      my_library << first_copy
      my_library.delete(first_copy)
      expect { my_library.delete(first_copy) }.to raise_error ArgumentError
    end

    it "allows multiple copies of a book to be added and deleted in turn" do
      first_copy = an_artist_of_the_floating_world
      my_library << first_copy
      my_library.delete(first_copy)

      second_copy = an_artist_of_the_floating_world
      my_library << second_copy
      third_copy = an_artist_of_the_floating_world
      my_library << third_copy

      expect { my_library.delete(second_copy) }.not_to raise_error
    end
  end

  describe ".import_as_isbn_list" do
    before do
      libraries = Alexandria::LibraryCollection.instance
      library = described_class.new("Test Library")
      libraries.add_library(library)

      allow(Alexandria::BookProviders)
        .to receive(:isbn_search)
        .and_raise Alexandria::BookProviders::SearchEmptyError
      allow(Alexandria::BookProviders)
        .to receive(:isbn_search).with("0595371086")
        .and_return(an_artist_of_the_floating_world)
    end

    it "imports books with correct isbn and search result" do
      library, bad_isbns, failed_lookup_isbns =
        described_class.import_as_isbn_list("Test Library", "spec/data/isbns.txt",
                                            proc { nil }, proc { nil })

      aggregate_failures do
        expect(library.to_a).to eq [an_artist_of_the_floating_world]
        expect(bad_isbns).to eq ["0911826449"]
        expect(failed_lookup_isbns).to eq ["0740704923"]
      end
    end
  end

  context "when importing from 0.6.1 data files" do
    let(:libs) { loader.load_all_libraries }
    let(:my_library) { libs[0] }

    before do
      lib_version = File.join(LIBDIR, "0.6.1")
      FileUtils.cp_r(lib_version, TESTDIR)
    end

    it "can be loaded" do
      expect(libs.size).to eq(1)
      expect(my_library.size).to eq(3)
    end

    it "imports cleanly from version 0.6.1 data format" do
      # Malory
      malory_book = my_library.find { |b| b.isbn == "9780192812179" }
      expect(malory_book.publisher).to eq("Oxford University Press")
      expect(malory_book.authors.include?("Vinaver")).to be_truthy
      expect(malory_book.version).to eq(Alexandria::DATA_VERSION)

      # Guide to LaTeX
      latex_book = my_library.find { |b| b.title.include? "Latex" }
      expect(latex_book.isbn).to eq("9780201398250")
      expect(latex_book.publisher).to eq("Addison Wesley") # note, no Ruby-Amazon cruft
    end
  end

  context "when importing from 0.6.1 with books without an ISBN" do
    let(:libs) { loader.load_all_libraries }
    let(:my_library) { libs[0] }

    before do
      lib_version = File.join(LIBDIR, "0.6.1-noisbn")
      FileUtils.cp_r(lib_version, TESTDIR)
    end

    after do
      FileUtils.rm_rf(TESTDIR)
    end

    it "can be loaded" do
      expect(libs.size).to eq(1)
      expect(my_library.size).to eq(2)
    end

    it "loads a book with ISBN" do
      # Guide to LaTeX
      latex_book = my_library.find { |b| b.title.include? "Latex" }
      expect(latex_book.isbn).to eq("9780201398250")
      expect(latex_book.publisher).to eq("Addison Wesley") # note, no Ruby-Amazon cruft
      expect(latex_book.version).to eq(Alexandria::DATA_VERSION)
    end

    it "loads a book without ISBN" do
      # Lex and Yacc
      lex_and_yacc_book = my_library.find { |b| b.title.include? "Lex" }
      expect(lex_and_yacc_book.publisher).to eq("O'Reilley")
    end

    it "saves loaded books properly" do
      my_library.each { |book| my_library.save(book, true) }
      my_library_reloaded = loader.load_all_libraries[0]
      expect(my_library_reloaded.size).to eq(2)

      latex_book = my_library_reloaded.find { |b| b.title.include? "Latex" }
      expect(latex_book.publisher).to eq("Addison Wesley")

      lex_and_yacc_book = my_library_reloaded.find { |b| b.title.include? "Lex" }
      expect(lex_and_yacc_book.publisher).to eq("O'Reilley")
    end
  end

  describe ".move" do
    let(:source) { loader.load_library("My Library") }
    let(:target) { loader.load_library("Target") }
    let(:book) { source.first }

    before do
      lib_version = File.join(LIBDIR, "0.6.2")
      FileUtils.cp_r(lib_version, TESTDIR)
    end

    it "changes the number of books in the source and target libraries" do
      count = source.count

      described_class.move(source, target, book)

      aggregate_failures do
        expect(source.count).to eq count - 1
        expect(target.count).to eq 1
      end
    end

    it "moves the book files from source to target" do
      described_class.move(source, target, book)

      aggregate_failures do
        expect(File.exist?(source.yaml(book))).to be_falsey
        expect(File.exist?(source.cover(book))).to be_falsey
        expect(File.exist?(target.yaml(book))).to be_truthy
        expect(File.exist?(target.cover(book))).to be_truthy
      end
    end
  end
end
