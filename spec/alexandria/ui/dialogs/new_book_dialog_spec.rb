# frozen_string_literal: true

# This file is part of the Alexandria build system.
#
# See the file README.md for authorship and licensing information.

require 'spec_helper'

describe Alexandria::UI::NewBookDialog do
  let(:parent) { Gtk::Window.new :toplevel }
  let(:model) { Gtk::ListStore.new(String, String, GdkPixbuf::Pixbuf) }

  it 'should work' do
    described_class.new parent
  end

  it 'can copy search results into result treeview' do
    results = [[an_artist_of_the_floating_world, 'cover-url']]
    dialog = described_class.new parent
    dialog.copy_results_to_treeview_model results, model
  end
end
