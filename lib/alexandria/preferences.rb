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

## require 'gconf2'
require 'alexandria/default_preferences'

module Alexandria
  class Preferences
    include Singleton
    include Logging

    def exec_gconf_set_list(var_path, new_value)
      list_type = "string"
      list = new_value.inspect # this produces e.g. "[\"a\", \"b\", \"c\"]"
      ##ret = `gconftool-2 --type list --list-type #{list_type} --set #{var_path} #{list}`
    end

    def exec_gconf_set(var_path, new_value)
      type = "string"
      list = new_value.inspect # this produces e.g. "[\"a\", \"b\", \"c\"]"
      ##ret = `gconftool-2 --type #{type} --set #{var_path} #{new_value.inspect}`
    end

    def initialize
      ## @client = GConf::Client.default
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
 
        var_path = APP_DIR + variable_name
       
        begin
          if new_value.is_a?(Array)
            # when setting array, first remove nil elements (fixing #9007)
            new_value.compact!
            if new_value.empty?
              remove_preference(variable_name)
            else
              # set list value
              exec_gconf_set_list(var_path, new_value)
              # @client[APP_DIR + variable_name] = new_value
            end
          else            
            # set non-list value
            exec_gconf_set(var_path, new_value)
            # @client[APP_DIR + variable_name] = new_value
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
        var_path = APP_DIR + method

        #value = @client[APP_DIR + method]
        exec_gconf_get(method, var_path)
        # value == nil ? DEFAULT_VALUES[method] : value
      end
    end

    def remove_preference(name)
      var_path = APP_DIR + name
      exec_gconf_unset(var_path)      
    end
    

    def exec_gconf_unset(var_path)
      `gconftool-2 --unset #{var_path}`
    end

    # type is one of int|bool|float|string|list|pair
    def convert_for_type(type, value)

      if type == "string"
        value
      elsif type == "int"
        value.to_i
      elsif type == "float"
        value.to_f
      elsif type == "bool"
        value == "true"
      elsif type == "list"
        value =~ /\[[^\]]\]/
        $1.split(",")
      elsif type == "pair"
        # dunno! # TODO fix this
        value.split(",")
      end
    end

    def exec_gconf_get(method, var_path)
      if method != :blah
        return DEFAULT_VALUES[method]
      end
      puts "gconftool-2 --get-type #{var_path}"
      type = `gconftool-2 --get-type #{var_path}`
      type.chomp!
      puts "type #{type}"
      puts "gconftool-2 --get #{var_path}"
      value = `gconftool-2 --get #{var_path}`
      if value.empty?
        value = DEFAULT_VALUES[method]
      else
        value.chomp!
        value = convert_for_type(type, value)
        puts value.inspect
      end
      value
    end

    def exec_gconf_system(type, var_path)
      value = `gconftool-2 --get #{var_path}`
      if value.empty?
        value = nil
      else
        value.chomp!
        value = convert_for_type(type, value)
      end
      value
    end

    URL_HANDLERS_DIR = "/desktop/gnome/url-handlers/"
    def www_browser
      dir = URL_HANDLERS_DIR + "http/"
      http_enabled = exec_gconf_system("bool", dir + "enabled")
      if http_enabled
        http_command = exec_gconf_system("string", dir + "command")
        http_command
      else
        nil
      end
    end

    def email_client
      dir = URL_HANDLERS_DIR + "mailto/"
      mailto_enabled = exec_gconf_system("bool", dir + "enabled")
      if mailto_enabled
        mailto_command = exec_gconf_system("string", dir + "command")
        mailto_command
      else
        nil
      end
    end

    def http_proxy_config
      use_http_proxy = exec_gconf_system("bool", "/system/http_proxy/use_http_proxy")
      proxy_mode = exec_gconf_system("string", "/system/proxy/mode") 
      if use_http_proxy && (proxy_mode == "manual")
        proxy = "/system/http_proxy/"
        host = exec_gconf_system("string", proxy + "host")
        port = exec_gconf_system("int", proxy + "port")
        user = exec_gconf_system("string", proxy + "authentication_user")
        pass = exec_gconf_system("string", proxy + "authentication_n_password")

        [ host, port, user, pass ] if (host && port)
      end
    end
  end
end
