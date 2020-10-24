# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

describe Alexandria::BookProviders do
  it "should be less clever"

  describe Alexandria::BookProviders::AmazonProvider do
    before do
      skip "Amazon requires an API key. Remove it altogether as a provider?"
    end

    it "does not piss off Rich Burridge" do
      assert_correct_search_result(described_class, "033025068X")
    end

    it "works" do
      assert_correct_search_result(described_class, "9780385504201")
    end

    it "works when searching for title" do
      assert_correct_search_result(described_class, "A Confederacy of Dunces",
                                   Alexandria::BookProviders::SEARCH_BY_TITLE)
    end

    it "amazon authors should work" do
      assert_correct_search_result(described_class, "John Kennedy Toole",
                                   Alexandria::BookProviders::SEARCH_BY_AUTHORS)
    end

    it "amazon keyword should work" do
      assert_correct_search_result(described_class, "Confederacy Dunces",
                                   Alexandria::BookProviders::SEARCH_BY_KEYWORD)
    end
  end

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
      skip "Not working: connect failed"
      assert_correct_search_result(described_class, "9781853260803")
    end
  end

  describe Alexandria::BookProviders::SBNProvider do
    it "works" do
      assert_correct_search_result(described_class, "9788835926436")
    end
  end

  describe Alexandria::BookProviders::BarnesAndNobleProvider do
    it "works" do
      skip "Barnes and Noble is not operational at the moment"
      assert_correct_search_result(described_class, "9780961328917") # see #1433
    end
  end

  describe Alexandria::BookProviders::ProxisProvider do
    it "works" do
      skip "Needs fixing"
      assert_correct_search_result(described_class, "9789026965746")
      assert_correct_search_result(described_class, "9780586071403")
    end
  end

  describe Alexandria::BookProviders::ThaliaProvider do
    before do
      skip "Needs fixing"
    end

    it "works" do
      # german book
      assert_correct_search_result(described_class, "9783896673305")
      # international book
      assert_correct_search_result(described_class, "9780440241904")
      # movie dvd
      assert_correct_search_result(described_class, "4010232037824")
      # music cd
      assert_correct_search_result(described_class, "0094638203520")
    end
  end

  describe Alexandria::BookProviders::AdLibrisProvider do
    it "works" do
      skip "Needs fixing: site has changed"
      assert_correct_search_result(described_class, "9789100109332")
    end
  end

  describe Alexandria::BookProviders::SicilianoProvider do
    it "works" do
      skip "Needs fixing: no results found"
      assert_correct_search_result(described_class, "9788599170380")
    end
  end
end
