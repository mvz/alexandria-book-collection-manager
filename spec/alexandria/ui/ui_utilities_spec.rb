# Copyright (C) 2007 Joseph Method
#
# Alexandria is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# Alexandria is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with Alexandria; see the file COPYING.  If not,
# write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301 USA.

require File.dirname(__FILE__) + '/../../spec_helper'

# from completion_models
describe Gtk::Entry do
  it "should extend Gtk::Entry"
end

describe Alexandria::UI::CompletionModels do
  it "should work"
end

#from glade_base

describe Alexandria::UI::GladeBase do
  it "should be revisited"
end

# from icons

describe Gdk::Pixbuf do
  it "should extend Gdk::PixBuf"
end

describe Alexandria::UI::Icons do
  it "should aid identification"
end

#from libraries_combo

describe Gtk::ComboBox do
  it "should extend Gtk::ComboBox"
end

#from multi_drag_treeview

describe Gdk::Event do
  it "should extend Gdk::Event"
end

describe Gtk::TreeView do
  it "should extend Gtk::TreeView"
end

