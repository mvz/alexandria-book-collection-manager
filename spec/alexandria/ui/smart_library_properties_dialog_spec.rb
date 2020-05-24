# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + "/../../spec_helper"

describe Alexandria::UI::SmartLibraryPropertiesDialog do
  let(:parent) { Gtk::Window.new :toplevel }
  let(:loader) { Alexandria::LibraryStore.new(TESTDIR) }
  let(:smart_library) { Alexandria::SmartLibrary.new("Foo", [], :all, loader) }

  it "can be instantiated" do
    described_class.new parent, smart_library
  end

  describe "#handle_ok_response" do
    it "returns true" do
      dialog = described_class.new parent, smart_library
      result = dialog.handle_ok_response

      expect(result).to be_truthy
    end
  end
end
