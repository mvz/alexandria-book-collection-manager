# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/error_dialog"

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

class Gtk::ActionGroup
  def [](x)
    get_action(x)
  end
end

class Gtk::IconView
  def freeze
    @old_model = model
    self.model = nil
  end

  def unfreeze
    self.model = @old_model
  end
end

class Gtk::TreeView
  def freeze
    @old_model = model
    self.model = nil
  end

  def unfreeze
    self.model = @old_model
  end
end

class Alexandria::Library
  def action_name
    "MoveIn" + name.gsub(/\s/, "")
  end
end

class Alexandria::BookProviders::AbstractProvider
  def action_name
    "At" + name
  end
end

module Alexandria
  module UI
    def self.display_help(parent, section = nil)
      section_index = ""
      section_index = "##{section}" if section
      exec("gnome-help ghelp:alexandria#{section_index}") if fork.nil?
    rescue StandardError
      log.error(self) { "Unable to load help browser" }
      ErrorDialog.new(parent, _("Unable to launch the help browser"),
                      _("Could not display help for Alexandria. " \
                        "There was an error launching the system " \
                        "help browser.")).display
    end
  end
end
