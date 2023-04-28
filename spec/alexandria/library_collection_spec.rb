# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

RSpec.describe Alexandria::LibraryCollection do
  describe "#ruined_books" do
    before do
      test_library = File.join(LIBDIR, "0.6.2")
      FileUtils.cp_r(test_library, TESTDIR)
    end

    it "lists ISBNs of empty files with their libraries" do
      FileUtils.touch File.join(TESTDIR, "My Library", "0740704923.yaml")
      collection = described_class.instance
      collection.reload
      library = collection.all_libraries.first
      expect(collection.ruined_books).to eq [[nil, "0740704923", library]]
    end
  end
end
