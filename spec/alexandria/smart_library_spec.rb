# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

RSpec.describe Alexandria::SmartLibrary do
  it "can be instantiated simply" do
    lib = described_class.new("Hello", [], :all)
    expect(lib.name).to eq "Hello"
  end

  describe "#name" do
    it "normalizes the encoding" do
      bad_name = (+"Prêts").force_encoding("ascii")
      lib = described_class.new(bad_name, [], :all)
      expect(lib.name.encoding.name).to eq "UTF-8"
      expect(bad_name.encoding.name).to eq "US-ASCII"
    end
  end

  describe "#update" do
    let(:lib) { described_class.new("Hello", [], :all) }

    it "works when given no parameters" do
      lib.update
    end

    it "works when given a LibraryCollection" do
      lib.update Alexandria::LibraryCollection.instance
    end

    it "works when given a Library" do
      lib.update Alexandria::Library.new("Hi")
    end
  end
end
