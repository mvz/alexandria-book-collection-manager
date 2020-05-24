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

  describe "#acquire" do
    let(:properties_dialog) { described_class.new parent, smart_library }
    let(:gtk_dialog) { properties_dialog.dialog }

    it "works when response is cancel" do
      allow(gtk_dialog).to receive(:run).and_return(Gtk::ResponseType::CANCEL)
      properties_dialog.acquire
    end

    it "works when response is ok" do
      allow(gtk_dialog).to receive(:run).and_return(Gtk::ResponseType::OK)
      properties_dialog.acquire
    end
  end
end
