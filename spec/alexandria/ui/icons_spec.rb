# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

RSpec.describe Alexandria::UI::Icons do
  describe ".tag_icon" do
    let(:loader) { Alexandria::LibraryStore.new(TESTDIR) }
    let(:lib_version) { File.join(LIBDIR, "0.6.2") }

    before do
      FileUtils.cp_r(lib_version, TESTDIR)
    end

    it "returns a pixbuf" do
      library = loader.load_all_libraries.first
      icon = described_class.cover(library, library.first)

      tagged_icon = described_class.tag_icon(icon, described_class::FAVORITE_TAG)
      expect(tagged_icon).to be_a GdkPixbuf::Pixbuf
    end
  end
end
