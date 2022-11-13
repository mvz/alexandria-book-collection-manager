# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::KeepBadISBNDialog do
  it "can be instantiated" do
    parent = Gtk::Window.new :toplevel
    book = instance_double(Alexandria::Book,
                           title: "Foo Book",
                           isbn: "98765432")
    expect { described_class.new parent, book }.not_to raise_error
  end
end
