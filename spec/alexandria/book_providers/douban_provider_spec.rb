# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

RSpec.describe Alexandria::BookProviders::DoubanProvider do
  describe "#url" do
    it "returns nil" do
      book = an_artist_of_the_floating_world
      url = described_class.instance.url(book)
      expect(url).to be_nil
    end
  end
end
