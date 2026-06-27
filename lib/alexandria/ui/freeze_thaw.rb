# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module UI
    module FreezeThaw
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

    Gtk::IconView.include FreezeThaw
    Gtk::TreeView.include FreezeThaw
  end
end
