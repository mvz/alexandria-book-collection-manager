# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::SidePaneManager do
  it 'works' do
    library_listview = double(Gtk::TreeView).as_null_object
    parent = double(Object, main_app: nil, append_library: nil)
    described_class.new library_listview, parent
  end
end
