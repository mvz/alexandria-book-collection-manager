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
      expect { lib.update }.not_to raise_error
    end

    it "works when given a LibraryCollection" do
      expect { lib.update Alexandria::LibraryCollection.instance }.not_to raise_error
    end

    it "works when given a Library" do
      expect { lib.update Alexandria::Library.new("Hi") }.not_to raise_error
    end
  end
end
