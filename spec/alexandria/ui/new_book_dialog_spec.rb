# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

describe Alexandria::UI::NewBookDialog do
  let(:parent) { Gtk::Window.new :toplevel }
  let(:model) do
    Gtk::ListStore.new([GObject::TYPE_STRING,
                        GObject::TYPE_STRING,
                        GdkPixbuf::Pixbuf.gtype])
  end

  it "works" do
    described_class.new parent
  end

  it "can copy search results into result treeview" do
    results = [[an_artist_of_the_floating_world, "cover-url"]]
    dialog = described_class.new parent
    dialog.copy_results_to_treeview_model results, model
  end
end
