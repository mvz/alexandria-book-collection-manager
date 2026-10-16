# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

Gtk.load_class :ActionGroup

module Alexandria
  module UI
    module GtkActionGroupOverrides
      def [](index)
        get_action(index)
      end
    end

    Gtk::ActionGroup.prepend GtkActionGroupOverrides
  end
end
