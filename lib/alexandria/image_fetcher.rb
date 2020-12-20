# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/net"

module Alexandria
  module ImageFetcher
    def fetch_image(uri)
      result = nil
      if URI.parse(uri).scheme.nil?
        File.open(uri, "r") do |io|
          result = io.read
        end
      else
        result = WWWAgent.new.get(uri)
      end
      result
    rescue Errno::ECONNRESET
      nil
    end
  end
end
