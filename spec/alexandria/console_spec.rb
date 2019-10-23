# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

RSpec.describe Alexandria do
  let(:lib_version) { File.join(LIBDIR, "0.6.2") }

  before do
    FileUtils.rm_rf(TESTDIR)
    FileUtils.cp_r(lib_version, TESTDIR)
  end

  after do
    FileUtils.rm_rf(TESTDIR)
  end

  describe ".list_books_on_console" do
    it "returns a string containing a list of all books" do
      expect(described_class.list_books_on_console).to eq <<~LIST
        The Dispossessed, Ursula Le Guin
        Pattern Recognition, William Gibson
        Bonjour Tristesse, Francoise Sagan & Irene Ash
        An Artist of the Floating World, Kazuo Ishiguro
        Neverwhere, Neil Gaiman
      LIST
    end
  end
end
