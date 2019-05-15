# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::IconViewManager do
  it 'works' do
    iconview = instance_double(Gtk::IconView).as_null_object
    parent = instance_double(Alexandria::UI::UIManager, iconview: iconview).as_null_object
    described_class.new iconview, parent
  end
end
