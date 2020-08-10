# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::SidepaneManager do
  it "works" do
    library_listview = instance_double(Gtk::TreeView).as_null_object
    parent = instance_double(Alexandria::UI::UIManager, main_app: nil, append_library: nil)
    described_class.new library_listview, parent
  end
end
