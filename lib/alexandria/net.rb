# Copyright (C) 2009 Cathal Mc Ginley
# Copyright (C) 2014 Matijs van Zuijlen
#
# This file is part of Alexandria.
#
# Alexandria is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# Alexandria is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with Alexandria; see the file COPYING.  If not,
# write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301 USA.

module Alexandria
  class WWWAgent
    def initialize
      user_agent = "Ruby #{RUBY_VERSION} #{Alexandria::TITLE}/#{Alexandria::VERSION}"
      @extra_request_headers = { 'User-Agent' => user_agent }
    end

    def self.transport
      config = Alexandria::Preferences.instance.http_proxy_config
      config ? Net::HTTP.Proxy(*config) : Net::HTTP
    end

    def get(url)
      uri = URI.parse(url)
      req = Net::HTTP::Get.new(uri.request_uri)
      @extra_request_headers.each_pair do |header_name, value|
        req.add_field(header_name, value)
      end
      res = WWWAgent.transport.start(uri.host, uri.port) {|http|
        http.request(req)
      }
      res
    end

    def language=(lang)
      @extra_request_headers['Accept-Language'] = lang.to_s
    end

    def user_agent=(agent_string)
      @extra_request_headers['User-Agent'] = agent_string
    end
  end
end
