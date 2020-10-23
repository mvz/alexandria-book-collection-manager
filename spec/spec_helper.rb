# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "rspec"
require "alexandria"
require "webmock/rspec"

LIBDIR = File.expand_path("data/libraries", __dir__)
TESTDIR = File.join(LIBDIR, "test")

def an_artist_of_the_floating_world
  Alexandria::Book.new("An Artist of the Floating World",
                       ["Kazuo Ishiguro"],
                       "9780571147168",
                       "Faber and Faber", 1999,
                       "Paperback")
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
