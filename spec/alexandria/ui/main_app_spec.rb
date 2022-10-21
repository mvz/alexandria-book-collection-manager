# frozen_string_literal: true


# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::MainApp do
  it "is a singleton" do
    expect do
      described_class.new
    end.to raise_error NoMethodError
  end
end
