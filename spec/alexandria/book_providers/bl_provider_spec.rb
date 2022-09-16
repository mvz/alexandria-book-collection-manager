# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

describe Alexandria::BookProviders::BLProvider do
  it "works" do
    expect(described_class).to have_correct_search_result_for "9781853260803"
  end
end
