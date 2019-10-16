# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::SkipEntryDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    described_class.new parent, 'Foo'
  end
end
