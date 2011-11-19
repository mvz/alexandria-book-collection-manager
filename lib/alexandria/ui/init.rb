# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2008 Joseph Method
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

class CellRendererToggle < Gtk::CellRendererToggle
  attr_accessor :text
  type_register
  install_property(GLib::Param::String.new(
        "text",
        "text",
        "Some damn value",
        "",
        GLib::Param::READABLE|GLib::Param::WRITABLE))
end

class Gtk::ActionGroup
  def [](x)
    get_action(x)
  end
end

class Gtk::IconView
  def freeze
    @old_model = self.model
    self.model = nil
  end

  def unfreeze
    self.model = @old_model
  end
end

class Gtk::TreeView
  def freeze
    @old_model = self.model
    self.model = nil
  end

  def unfreeze
    self.model = @old_model
  end
end

class Alexandria::Library
  def action_name
    "MoveIn" + name.gsub(/\s/, '')
  end
end

class Alexandria::BookProviders::AbstractProvider
  def action_name
    "At" + name
  end
end

module Pango
  def self.ellipsizable?
    @ellipsizable ||= Pango.constants.include?('ELLIPSIZE_END')
  end
end

module Alexandria
  module UI
    def self.display_help(parent=nil, section=nil)
      begin
        # TODO this should call Gtk.show_uri, but it's not included
        # in ruby-gnome2 yet
        section_index = ''
        if section
          section_index = "##{section}"
        end
        exec("gnome-help ghelp:alexandria#{section_index}") if fork.nil?
      rescue Exception => e
        log.error(self) { "Unable to load help browser" }
        ErrorDialog.new(parent, _("Unable to launch the help browser"),
                        _("Could not display help for Alexandria. " +
                          "There was an error launching the system " +
                          "help browser."))
      end
    end
  end
end
