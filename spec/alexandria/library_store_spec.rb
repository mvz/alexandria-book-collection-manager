# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

RSpec.describe Alexandria::LibraryStore do
  let(:loader) { described_class.new(TESTDIR) }

  describe "#load_all_smart_libraries" do
    context "when none exist" do
      it "creates and saves some" do
        smart_libs = loader.load_all_smart_libraries
        aggregate_failures do
          expect(smart_libs.size).to eq 5
          smart_libs.each do |lib|
            expect(lib.yaml).to be_an_existing_file
          end
        end
      end
    end

    context "when one exists" do
      it "returns the existing smart library" do
        existing = Alexandria::SmartLibrary.new("Hi", [], :all, loader)
        existing.save
        smart_libs = loader.load_all_smart_libraries
        aggregate_failures do
          expect(smart_libs.size).to eq 1
          expect(smart_libs.first.yaml).to eq existing.yaml
        end
      end
    end
  end

  describe "#load_all_libraries" do
    before do
      test_library = File.join(LIBDIR, "0.6.2")
      FileUtils.cp_r(test_library, TESTDIR)
    end

    it "loads the libraries in the target directory" do
      result = loader.load_all_libraries
      aggregate_failures do
        expect(result.count).to eq 1
        expect(result.first.map(&:title))
          .to match_array ["Pattern Recognition", "Bonjour Tristesse",
                           "An Artist of the Floating World", "The Dispossessed",
                           "Neverwhere"]
      end
    end

    it "lists ISBNs of empty files in ruined books" do
      FileUtils.touch File.join(TESTDIR, "My Library", "0740704923.yaml")
      result = loader.load_all_libraries
      library = result.first
      expect(library.ruined_books).to match_array ["0740704923"]
    end

    it "skips empty files with names that are not valid ISBNs" do
      FileUtils.touch File.join(TESTDIR, "My Library", "12345.yaml")
      result = loader.load_all_libraries
      library = result.first
      expect(library.ruined_books).to be_empty
    end
  end
end
