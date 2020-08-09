# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::BookPropertiesDialog do
  it "works" do
    parent = Gtk::Window.new :toplevel
    library = instance_double(Alexandria::Library, name: "Bar Library", cover: "")
    book = Alexandria::Book.new("Foo Book", ["Jane Doe"], "98765432", "Bar Publisher",
                                1972, "edition")
    described_class.new parent, library, book
  end
end
