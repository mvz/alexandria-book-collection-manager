# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module UI
    module LibraryOverrides
      def action_name
        "MoveIn" + name.gsub(/\s/, "")
      end
    end
    Library.prepend LibraryOverrides
  end
end
