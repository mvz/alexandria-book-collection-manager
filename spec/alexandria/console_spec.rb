# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

RSpec.describe Alexandria do
  let(:lib_version) { File.join(LIBDIR, "0.6.2") }

  before do
    FileUtils.cp_r(lib_version, TESTDIR)
  end

  describe ".list_books_on_console" do
    it "returns a string containing a list of all books" do
      expect(described_class.list_books_on_console).to eq <<~LIST
        Pattern Recognition, William Gibson
        Bonjour Tristesse, Francoise Sagan & Irene Ash
        An Artist of the Floating World, Kazuo Ishiguro
        The Dispossessed, Ursula Le Guin
        Neverwhere, Neil Gaiman
      LIST
    end
  end
end
