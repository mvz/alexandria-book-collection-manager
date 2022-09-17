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

RSpec::Matchers.define :have_correct_search_result_for do |query|
  match(notify_expectation_failures: true) do |provider|
    begin
      results = provider.instance.search(query, Alexandria::BookProviders::SEARCH_BY_ISBN)
    rescue SocketError
      skip "Service is offline"
    end

    expect(results).to be_instance_of(Array)
    expect(results).not_to be_empty
    expect(results.length).to be <= 2

    book, cover_url = *results

    expect(book).to be_instance_of(Alexandria::Book)

    canonical_query = Alexandria::Library.canonicalise_ean(query)
    canonical_result = Alexandria::Library.canonicalise_ean(book.isbn)
    expect(canonical_query).to eq(canonical_result)

    expect(cover_url).to be_instance_of(String) if cover_url

    true
  end
end

RSpec::Matchers.define :be_an_existing_file do
  match do |filename|
    File.exist? filename
  end
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
