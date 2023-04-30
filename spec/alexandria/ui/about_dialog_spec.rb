# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::AboutDialog do
  it "can be instantiated" do
    parent = Gtk::Window.new :toplevel
    obj = described_class.new parent
    expect(obj).to be_a described_class

    # NOTE: Dialog must be destroyed to avoid a TypeError after the spec run
    # (visible when running ruby in debug mode).
    obj.destroy
  end
end
