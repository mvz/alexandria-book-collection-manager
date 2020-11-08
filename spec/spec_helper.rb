# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "rspec"
require "alexandria"
require "webmock/rspec"
require "pry"

LIBDIR = File.expand_path("data/libraries", __dir__)
TESTDIR = File.join(LIBDIR, "test")

def an_artist_of_the_floating_world
  Alexandria::Book.new("An Artist of the Floating World",
                       ["Kazuo Ishiguro"],
                       "9780571147168",
                       "Faber and Faber", 1999,
                       "Paperback")
end

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

Alexandria::UI::Icons.init

test_store = Alexandria::LibraryStore.new(TESTDIR)
Alexandria::LibraryCollection.instance.library_store = test_store

RSpec.configure do |config|
  config.example_status_persistence_file_path = "spec/examples.txt"

  config.before do
    FileUtils.rm_rf(TESTDIR)
  end

  config.after do
    FileUtils.rm_rf(TESTDIR)
  end
end
