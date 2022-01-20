# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

describe Alexandria::BookProviders::SBNProvider do
  it "works" do
    assert_correct_search_result(described_class, "9788835926436")
  end
end
