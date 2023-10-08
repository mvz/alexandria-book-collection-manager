# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require_relative "../../spec_helper"

describe Alexandria::UI::IconViewManager do
  it "can be instantiated" do
    iconview = instance_double(Gtk::IconView).as_null_object
    parent = instance_double(Alexandria::UI::UIManager, iconview: iconview).as_null_object
    expect { described_class.new iconview, parent }.not_to raise_error
  end
end
