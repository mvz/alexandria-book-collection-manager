# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

describe Alexandria::BookProviders do
  it "should be less clever"

  describe Alexandria::BookProviders::LOCProvider do
    it "works for a book with ASCII title" do
      assert_correct_search_result(described_class, "9780805335583")
    end

    it "works for a book with a title with non-ASCII letters" do
      assert_correct_search_result(described_class, "9782070379248")
    end
  end

  describe Alexandria::BookProviders::BLProvider do
    it "works" do
      assert_correct_search_result(described_class, "9781853260803")
    end
  end

  describe Alexandria::BookProviders::SBNProvider do
    it "works" do
      assert_correct_search_result(described_class, "9788835926436")
    end
  end
end
