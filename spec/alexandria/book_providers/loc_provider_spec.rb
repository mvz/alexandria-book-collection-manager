# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

describe Alexandria::BookProviders::LOCProvider do
  it "works for a book with ASCII title" do
    expect(described_class).to have_correct_search_result_for "9780805335583"
  end

  it "works for a book with a title with non-ASCII letters" do
    expect(described_class).to have_correct_search_result_for "9782070379248"
  end

  describe "#url" do
    it "returns nil" do
      book = an_artist_of_the_floating_world
      url = described_class.instance.url(book)
      expect(url).to be_nil
    end
  end
end
