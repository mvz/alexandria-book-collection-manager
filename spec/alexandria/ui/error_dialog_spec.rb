# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::ErrorDialog do
  it "works" do
    parent = Gtk::Window.new :toplevel
    expect { described_class.new parent, "Boom", "It went boom" }.not_to raise_error
  end
end
