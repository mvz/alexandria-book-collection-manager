# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require File.dirname(__FILE__) + '/../../spec_helper'

describe Alexandria::UI::KeepBadISBNDialog do
  it 'works' do
    parent = Gtk::Window.new :toplevel
    book = instance_double(Alexandria::Book,
                           title: 'Foo Book',
                           isbn: '98765432')
    described_class.new parent, book
  end
end
