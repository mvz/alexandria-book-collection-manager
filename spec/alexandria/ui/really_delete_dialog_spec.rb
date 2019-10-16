# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::ReallyDeleteDialog do
  it 'works' do
    library = instance_double(Alexandria::Library, name: 'Bar Library', empty?: false, size: 12)
    parent = Gtk::Window.new :toplevel
    described_class.new parent, library
  end
end
