# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require 'spec_helper'

describe Alexandria::Library do
  let(:loader) { Alexandria::LibraryStore.new(TESTDIR) }

  describe '::EXT' do
    it 'has symbolic references to file extensions' do
      extensions = Alexandria::Library::EXT
      expect(extensions[:book]).not_to be_nil
      expect(extensions[:cover]).not_to be_nil
    end
  end

  describe '#valid_isbn?' do
    it 'returns a true value for valid isbns' do
      ['014143984X', '0-345-43192-8'].each do |x|
        expect(described_class.valid_isbn?(x)).to be_truthy
      end
    end
  end

  describe '#valid_ean?' do
    it 'returns a true value for valid EANs' do
      expect(described_class.valid_ean?('9780345431929')).to be_truthy
      expect(described_class.valid_ean?('978034543192912345')).to be_truthy

      # Regression test: this EAN has a checksum of 10, which should be
      # treated like a checksum of 0.
      expect(described_class.valid_ean?('9784047041790')).to be_truthy
    end

    it 'returns a false value for invalid EANs' do
      expect(described_class.valid_ean?('780345431929')).to be_falsey
      expect(described_class.valid_ean?('97803454319290')).to be_falsey
      expect(described_class.valid_ean?('97803454319291234')).to be_falsey
      expect(described_class.valid_ean?('9780345431929123456')).to be_falsey
      expect(described_class.valid_ean?('9780345431928')).to be_falsey
      expect(described_class.valid_ean?('9780345431929A')).to be_falsey

      expect(described_class.valid_ean?('9784047041791')).to be_falsey
    end
  end

  describe '#valid_upc?' do
    it 'returns a true value for valid UPCs' do
      expect(described_class.valid_upc?('97803454319312356')).to be_truthy
    end

    it 'returns a false value for invalid UPCs' do
      expect(described_class.valid_upc?('978034543193123567')).to be_falsey
      expect(described_class.valid_upc?('9780345431931235')).to be_falsey

      expect(described_class.valid_upc?('97803454319412356')).to be_falsey
      expect(described_class.valid_upc?('97803454319212356')).to be_falsey
    end
  end

  describe '#canonicalise_isbn' do
    it 'returns the correct value for several examples' do
      expect(described_class.canonicalise_isbn('014143984X')).to eq '014143984X'
      expect(described_class.canonicalise_isbn('0-345-43192-8')).to eq '0345431928'
      expect(described_class.canonicalise_isbn('3522105907')).to eq '3522105907'
      # EAN number
      expect(described_class.canonicalise_isbn('9780345431929')).to eq '0345431928'
    end
  end

  context 'with an empty library' do
    let(:my_library) { loader.load_library('Empty') }

    before do
      FileUtils.mkdir(TESTDIR) unless File.exist? TESTDIR
    end

    after do
      FileUtils.rm_rf(TESTDIR)
    end

    it 'disallows multiple deletion of the same copy of a book' do
      first_copy = an_artist_of_the_floating_world
      my_library << first_copy
      my_library.delete(first_copy)
      expect { my_library.delete(first_copy) }.to raise_error ArgumentError
    end

    it 'allows multiple copies of a book to be added and deleted in turn' do
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

  describe '.import_as_isbn_list' do
    def __test_fake_import_isbns
      libraries = Alexandria::LibraryCollection.instance
      library = Alexandria::Library.new('Test Library')
      libraries.add_library(library)
      [library, libraries]
    end

    it "doesn't work quite yet" do
      skip
      # Doesn't work quite yet.
      on_iterate_cb = proc {}
      on_error_cb = proc {}
      library, _libraries = __test_fake_import_isbns
      test_file = 'data/isbns.txt'
      library.import_as_isbn_list('Test Library', test_file, on_iterate_cb, on_error_cb)
    end
  end

  context 'imported from 0.6.1 data files' do
    before do
      lib_version = File.join(LIBDIR, '0.6.1')
      FileUtils.cp_r(lib_version, TESTDIR)
    end

    after do
      FileUtils.rm_rf(TESTDIR)
    end

    it 'imports cleanly from version 0.6.1 data format' do
      libs = loader.load_all_libraries
      expect(libs.size).to eq(1)
      my_library = libs[0]
      expect(my_library.size).to eq(3)
      # Malory
      malory_book = my_library.select { |b| b.isbn == '9780192812179' }[0]
      expect(malory_book.publisher).to eq('Oxford University Press')
      expect(malory_book.authors.include?('Vinaver')).to be_truthy
      expect(malory_book.version).to eq(Alexandria::DATA_VERSION)

      # Guide to LaTeX
      latex_book = my_library.select { |b| b.title.include? 'Latex' }[0]
      expect(latex_book.isbn).to eq('9780201398250')
      expect(latex_book.publisher).to eq('Addison Wesley') # note, no Ruby-Amazon cruft
    end
  end

  context 'imported from 0.6.1 with books without an ISBN' do
    before do
      lib_version = File.join(LIBDIR, '0.6.1-noisbn')
      FileUtils.cp_r(lib_version, TESTDIR)
    end

    after do
      FileUtils.rm_rf(TESTDIR)
    end

    it 'allows books to have no ISBN' do
      libs = loader.load_all_libraries
      expect(libs.size).to eq(1)
      my_library = libs[0]
      expect(my_library.size).to eq(2)

      # Guide to LaTeX
      latex_book = my_library.select { |b| b.title.include? 'Latex' }[0]
      expect(latex_book.isbn).to eq('9780201398250')
      expect(latex_book.publisher).to eq('Addison Wesley') # note, no Ruby-Amazon cruft
      expect(latex_book.version).to eq(Alexandria::DATA_VERSION)

      # Lex and Yacc
      lex_and_yacc_book = my_library.select { |b| b.title.include? 'Lex' }[0]
      expect(lex_and_yacc_book.publisher).to eq("O'Reilley")

      my_library.each do |book|
        my_library.save(book, true)
      end

      libraries_reloaded = loader.load_all_libraries
      my_library_reloaded = libraries_reloaded[0]

      expect(my_library_reloaded.size).to eq(2)

      latex_book = my_library_reloaded.select { |b| b.title.include? 'Latex' }[0]
      expect(latex_book).not_to be_nil
      expect(latex_book.publisher).to eq('Addison Wesley')

      lex_and_yacc_book = my_library_reloaded.select { |b| b.title.include? 'Lex' }[0]
      expect(lex_and_yacc_book).not_to be_nil
      expect(lex_and_yacc_book.publisher).to eq("O'Reilley")
    end
  end

  describe '.move' do
    before do
      lib_version = File.join(LIBDIR, '0.6.2')
      FileUtils.cp_r(lib_version, TESTDIR)
    end

    it 'moves the given book from source to target' do
      source = loader.load_library('My Library')
      count = source.count
      book = source.first
      target = loader.load_library('Target')

      described_class.move(source, target, source.first)

      aggregate_failures do
        expect(source.count).to eq count - 1
        expect(target.count).to eq 1
        expect(File.exist? source.yaml(book)).to be_falsey
        expect(File.exist? source.cover(book)).to be_falsey
        expect(File.exist? target.yaml(book)).to be_truthy
        expect(File.exist? target.cover(book)).to be_truthy
      end
    end
  end
end
