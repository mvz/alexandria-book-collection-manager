# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

describe Alexandria::BookProviders::Z3950Provider do
  let(:zoom_connection) { instance_double(ZOOM::Connection) }

  before do
    allow(ZOOM::Connection).to receive(:new).and_return zoom_connection
  end

  it "raises a custom error when a timeout occurs" do
    allow(zoom_connection).to receive(:connect).and_raise RuntimeError, "Timeout (10007)"
    expect do
      described_class.new.search("9781853260803", Alexandria::BookProviders::SEARCH_BY_ISBN)
    end.to raise_error Alexandria::BookProviders::ConnectionError
  end
end
