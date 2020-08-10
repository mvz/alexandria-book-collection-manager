# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::ExportDialog do
  it "works" do
    parent = Gtk::Window.new :toplevel
    library = instance_double(Alexandria::Library, name: "Bar Library")
    described_class.new parent, library, :ascending
  end
end
