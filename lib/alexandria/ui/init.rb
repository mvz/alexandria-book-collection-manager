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
        Gnome::Help.display('alexandria', section)
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
