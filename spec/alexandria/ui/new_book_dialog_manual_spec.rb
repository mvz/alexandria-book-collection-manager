# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::NewBookDialogManual do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    library = instance_double(Alexandria::Library)
    described_class.new parent, library
  end
end
