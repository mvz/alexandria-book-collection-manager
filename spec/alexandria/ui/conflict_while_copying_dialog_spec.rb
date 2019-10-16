# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::ConflictWhileCopyingDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    library = instance_double(Alexandria::Library, name: 'Bar Library')
    book = instance_double(Alexandria::Book, title: 'Foo Book')
    described_class.new parent, library, book
  end
end
