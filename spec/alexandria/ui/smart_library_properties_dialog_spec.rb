# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + "/../../spec_helper"

describe Alexandria::UI::SmartLibraryPropertiesDialog do
  it "works" do
    parent = Gtk::Window.new :toplevel
    smart_library = instance_double(Alexandria::SmartLibrary,
                                    name: "Foo",
                                    rules: [],
                                    predicate_operator_rule: :any)
    described_class.new parent, smart_library
  end
end
