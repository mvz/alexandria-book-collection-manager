# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::ConflictWhileCopyingDialog do
  it "can be instantiated" do
    parent = Gtk::Window.new :toplevel
    library = instance_double(Alexandria::Library, name: "Bar Library")
    book = instance_double(Alexandria::Book, title: "Foo Book")
    expect { described_class.new parent, library, book }.not_to raise_error
  end
end
