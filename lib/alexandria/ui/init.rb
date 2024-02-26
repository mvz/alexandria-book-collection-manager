# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/error_dialog"

module Gtk
  load_class :ActionGroup
  load_class :IconView
  load_class :TreeView
end

class Gtk::ActionGroup
  def [](index)
    get_action(index)
  end
end

module Alexandria::UI::FreezeThaw
  def self.included(base)
    base.class_eval do
      attr_accessor :old_model
    end
  end

  def frozen?
    old_model && !model
  end

  def freeze
    return if frozen?

    self.old_model = model
    self.model = nil
  end

  def unfreeze
    return unless frozen?

    self.model = old_model
    self.old_model = nil
  end
end

Gtk::IconView.include Alexandria::UI::FreezeThaw
Gtk::TreeView.include Alexandria::UI::FreezeThaw

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
