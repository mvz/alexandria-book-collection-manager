# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

describe Alexandria::BookProviders::SBNProvider do
  it "produces a valid search result" do
    expect(described_class).to have_correct_search_result_for "9788835926436"
  end

  describe "#url" do
    it "returns nil" do
      book = an_artist_of_the_floating_world
      url = described_class.instance.url(book)
      expect(url).to be_nil
    end
  end
end
