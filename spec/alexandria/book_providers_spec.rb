# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

describe Alexandria::BookProviders do
  it "should be less clever"

  def assert_correct_search_result(provider, query,
                                   search_type = Alexandria::BookProviders::SEARCH_BY_ISBN)
    begin
      results = provider.instance.search(query, search_type)
    rescue SocketError
      skip "Service is offline"
    end

    expect(results).to be_instance_of(Array), "Results are not an array for #{provider}"
    expect(results).not_to be_empty, "Results are empty for #{provider}"

    if search_type == Alexandria::BookProviders::SEARCH_BY_ISBN
      expect(results.length).to be <= 2, "Results are greater than 2 for #{provider}"

      book = results.first

      expect(book).to be_instance_of(Alexandria::Book),
                      "Result is not a Book for #{provider}"

      canonical_query = Alexandria::Library.canonicalise_ean(query)
      canonical_result = Alexandria::Library.canonicalise_ean(book.isbn)
      expect(canonical_query)
        .to eq(canonical_result),
            "Result's isbn #{book.isbn} is not equivalent" \
            " to the requested isbn #{query} for #{provider}"

      if results.length == 2
        cover_url = results.last
        if cover_url
          expect(cover_url)
            .to be_instance_of(String),
                "Unexpected cover_url #{cover_url.inspect} for #{provider}"
        end
      end
    else
      expect(results.first.first)
        .to be_instance_of(Alexandria::Book), "Result item is not a Book for #{provider}"
    end
    results
  end

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

  describe Alexandria::BookProviders::WorldCatProvider do
    it "works" do
      assert_correct_search_result(described_class,
                                   "9780521247108")
      # this one is with <div class=vernacular lang="[^"]+">)
      assert_correct_search_result(described_class,
                                   "9785941454136")
    end

    it "works with multiple authors" do
      results = assert_correct_search_result(described_class,
                                             "9785941454136")
      this_book = results.first
      expect(this_book.authors).to be_instance_of(Array), "Not an array!"
      # puts this_book.authors
      expect(this_book.authors.length).to eq(2), "Wrong number of authors for this book!"
    end
  end
end
