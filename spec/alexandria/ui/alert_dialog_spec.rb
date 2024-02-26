# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::AlertDialog do
  it "can be instantiated" do
    parent = Gtk::Window.new :toplevel
    expect do
      described_class.new(parent, "Hello",
                          Gtk::STOCK_DIALOG_QUESTION,
                          [[Gtk::STOCK_CANCEL, :cancel]], "Hi there")
    end.not_to raise_error
  end
end
