# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "gobject-introspection"

module Alexandria
  module UI
    module GooCanvas
      class << self
        def const_missing(name)
          init
          if const_defined?(name)
            const_get(name)
          else
            super
          end
        end

        def init
          class << self
            remove_method(:init)
            remove_method(:const_missing)
          end
          loader = GObjectIntrospection::Loader.new(self)
          loader.load("GooCanvas")
        end
      end
    end
  end
end
