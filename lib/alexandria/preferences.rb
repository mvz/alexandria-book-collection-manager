# Copyright (C) 2004-2006 Laurent Sansonetti
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

require 'singleton'

require 'gconf2'
require 'alexandria/default_preferences'

module Alexandria
  class Preferences
    include Singleton
    include Logging

    def initialize
      @client = GConf::Client.default
    end

    APP_DIR = "/apps/alexandria/"
    def method_missing(id, *args)
      method = id.id2name
      if match = /(.*)=$/.match(method)
        if args.length != 1
          raise "Set method #{method} should be called with " +
            "only one argument (was called with #{args.length})"
        end

        variable_name = match[1]
        new_value = args.first

        
        
        begin
          if new_value.is_a?(Array)
            # when setting array, first remove nil elements (fixing #9007)
            new_value.compact!
            if new_value.empty?
              remove_preference(variable_name)
            else
              @client[APP_DIR + variable_name] = new_value
            end
          else            
            @client[APP_DIR + variable_name] = new_value
          end
        rescue Exception => ex
          trace = ex.backtrace.join("\n> ")
          log.debug { new_value.inspect }
          log.error { "Fix GConf handling #{ex.message} #{trace}" }
        end
      else
        unless args.empty?
          raise "Get method #{method} should be called " +
            "without argument (was called with #{args.length})"
        end

        value = @client[APP_DIR + method]
        value == nil ? DEFAULT_VALUES[method] : value
      end
    end

    def remove_preference(name)
      @client.unset(APP_DIR + name)
    end

    URL_HANDLERS_DIR = "/desktop/gnome/url-handlers/"
    def www_browser
      dir = URL_HANDLERS_DIR + "http/"
      @client[dir + "command"] if @client[dir + "enabled"]
    end

    def email_client
      dir = URL_HANDLERS_DIR + "mailto/"
      @client[dir + "command"] if @client[dir + "enabled"]
    end

    def http_proxy_config
      if @client["/system/http_proxy/use_http_proxy"] and
          @client["/system/proxy/mode"] == "manual"

        host, port, user, pass = %w{host port authentication_user
                                            authentication_password}.map do |x|

          case y = @client["/system/http_proxy/" + x]
          when Integer
            y == 0 ? nil : y
          when String
            (y.strip.empty?) ? nil : y
          end
        end

        [ host, port, user, pass ] if host and port
      end
    end
  end
end

=begin
rescue LoadError

module Alexandria
    class Preferences
        include Singleton
        include OSX

        def initialize
            @userDefaults = NSUserDefaults.standardUserDefaults
            # register defaults here
        end

        def method_missing(id, *args)
            method = id.id2name
            if match = /(.*)=$/.match(method)
                if args.length != 1
                    raise "Set method #{method} should be called with " +
                          "only one argument (was called with #{args.length})"
                end
                puts "#{match[1]} -> #{args.first}"
                _sync { @userDefaults.setObject_forKey(args.first, match[1]) }
            else
                unless args.empty?
                    raise "Get method #{method} should be called " +
                          "without argument (was called with #{args.length})"
                end
                _convertToRubyObject(_sync { @userDefaults.objectForKey(method) })
            end
        end

        def remove_preference(name)
            @userDefaults.removeObjectForKey(name)
        end

        #######
        private
        #######

        def _sync(&p)
            if ExecutionQueue.current != nil
                ExecutionQueue.current.sync_call(p)
            else
                p.call
            end
        end

        def _convertToRubyObject(object)
            if object.nil?
                nil
            elsif object.isKindOfClass?(NSString.oc_class)
                object.to_s
            elsif object.isKindOfClass?(NSNumber.oc_class)
                object.intValue
            elsif object.isKindOfClass?(NSArray.oc_class)
                object.to_a.map { |x| _convertToRubyObject(x) }
            else
                nil
            end
        end
    end
end
end
=end
