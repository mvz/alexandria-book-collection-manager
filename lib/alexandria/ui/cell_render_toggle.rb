# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

class CellRendererToggle < Gtk::CellRendererToggle
  attr_accessor :text

  type_register
  install_property(GLib::Param::String.new(
                     "text",
                     "text",
                     "Some damn value",
                     "",
                     GLib::Param::READABLE | GLib::Param::WRITABLE))
end
