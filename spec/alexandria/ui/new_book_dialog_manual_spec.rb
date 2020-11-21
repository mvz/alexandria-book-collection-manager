# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::NewBookDialogManual do
  let(:parent) { Gtk::Window.new :toplevel }
  let(:library) {
    store = Alexandria::LibraryCollection.instance.library_store
    store.load_library("Bar Library")
  }
  let(:book) do
    Alexandria::Book.new("Foo Book", ["Jane Doe"], "98765432", "Bar Publisher",
                         1972, "edition")
  end

  it "works" do
    parent = Gtk::Window.new :toplevel
    library = instance_double(Alexandria::Library)
    described_class.new parent, library
  end
end
