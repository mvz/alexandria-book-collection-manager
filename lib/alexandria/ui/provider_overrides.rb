# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module UI
    module ProviderOverrides
      def action_name
        "At" + name
      end
    end

    BookProviders::AbstractProvider.prepend ProviderOverrides
  end
end
