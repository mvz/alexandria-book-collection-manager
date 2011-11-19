# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2011 Cathal Mc Ginley
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
require 'set'
require 'alexandria/default_preferences'

module Alexandria
  class Preferences
    include Singleton
    include Logging

    APP_DIR = "/apps/alexandria"
    HTTP_PROXY_DIR = "/system/http_proxy"
    HTTP_PROXY_MODE = "/system/proxy/mode"
    URL_HANDLERS_DIR = "/desktop/gnome/url-handlers"

    GCONFTOOL = "gconftool-2"

    def initialize()
      @alexandria_settings = {}
      @changed_settings = Set.new

      @url_handlers_loaded = false
      @http_command = nil
      @mailto_command = nil

      @proxy_settings_loaded = false
      @use_http_proxy = false
      @proxy_host = nil
      @proxy_port = nil
      @proxy_user = nil
      @proxy_password = nil

      load_alexandria_settings
      # load_system_settings
    end


    def www_browser
      unless @url_handlers_loaded
        load_url_handler_settings
      end
      puts @http_command
      @http_command
    end


    def email_client
      unless @url_handlers_loaded
        load_url_handler_settings
      end
      puts @mailto_command
      @mailto_command
    end

    def http_proxy_config
      unless @http_proxy_loaded
        load_http_proxy_settings
      end
      if (@use_http_proxy && @proxy_host && @proxy_port)
        [@proxy_host, @proxy_port, @proxy_user, @proxy_password]
      end
    end



    def save!
      log.debug { "preferences save!" }
      @changed_settings.each do |variable_name|
        log.debug {"saving preference #{variable_name} / #{@alexandria_settings[variable_name].class}" }
        generic_save_setting(variable_name, @alexandria_settings[variable_name])
      end
      @changed_settings.clear
    end


    def method_missing(id, *args)
      method = id.id2name
      if match = /(.*)=$/.match(method)
        if args.length != 1
          raise "Set method #{method} should be called with " +
            "only one argument (was called with #{args.length})"
        end
        variable_name = match[1]
        new_value = args.first
        generic_setter(variable_name, new_value)
      else
        unless args.empty?
          raise "Get method #{method} should be called " +
            "without argument (was called with #{args.length})"
        end
        generic_getter(method)
      end
    end
    
    def remove_preference(variable_name)
      @alexandria_settings.delete(variable_name)
      @changed_settings << variable_name
    end



    private



    ##
    ## GENERIC GETTER and SETTER CODE
    ##


    def generic_getter(variable_name)
      value = @alexandria_settings[variable_name]
      if value.nil?
        value = DEFAULT_VALUES[variable_name]          
        unless value.nil?
          @alexandria_settings[variable_name] = value
          @changed_settings << variable_name
        end
      end
      value
    end
    
    def generic_setter(variable_name, new_value)
      if new_value.is_a?(Array)
        # when setting array, first remove nil elements (fixing #9007)
        new_value.compact!
      end
      old_value = @alexandria_settings[variable_name]
      @alexandria_settings[variable_name] = new_value
      unless new_value == old_value 
        @changed_settings << variable_name
      end
    end

    def generic_save_setting(variable_name, new_value)
      begin
        var_path = APP_DIR + "/" + variable_name
        if new_value.is_a?(Array)
          # when setting array, first remove nil elements (fixing #9007)
          new_value.compact!
          if new_value.empty?
            exec_gconf_unset(variable_name)
          else
            # set list value
            exec_gconf_set_list(var_path, new_value)
          end
        else            
          # set non-list value
          if new_value.nil?
            exec_gconf_unset(variable_name)
          else
            exec_gconf_set(var_path, new_value)
          end
        end
      rescue Exception => ex
        log.debug { new_value.inspect }
        log.error { "Could not set GConf setting #{variable_name} to value: #{new_value.inspect}" }
        log << ex.message
        log << ex
      end
    end



    ##
    ## GCONFTOOL SET and SET LIST and SET PAIR and UNSET
    ##


    def get_gconf_type(value) 
      if value.is_a?(String)
        "string"
      elsif value.is_a?(Fixnum)
        "int"
      elsif value.is_a?(TrueClass) || value.is_a?(FalseClass)
        "bool"
      else
        "string"
      end
    end

    def exec_gconf_set_list(var_path, new_list)
      # NOTE we must check between list and pair...

      list_type = get_gconf_type(new_list.first)
      if list_type == 'int' && new_list.size == 2
        # treat this as a pair of int
        a = new_list[0]
        b = new_list[1]
        pair = "(#{a},#{b})"
        `gconftool-2 --type pair --car-type int --cdr-type int --set #{var_path} "#{pair}"`
      else
        list = make_list_string(new_list)
        `gconftool-2 --type list --list-type #{list_type} --set #{var_path} "#{list}"`
      end
    end

    def make_list_string(list)
      if get_gconf_type(list.first) == "string"
        list.map! {|x| x.gsub /\"/, "\\\"" }
      end
      contents = list.join(",")
      "[" + contents + "]"
    end

    def exec_gconf_set(var_path, new_value)
      if /cols_width/ =~ var_path
        puts new_value

        #new_value = {}
      end
      type = get_gconf_type(new_value)
      value_str = new_value
      if new_value.is_a? String
        new_value.gsub! /\"/, "\\\""
        value_str = "\"#{new_value}\""
      end
      if /cols_width/ =~ var_path
        puts value_str
      end
      ret = `gconftool-2 --type #{type} --set #{var_path} #{value_str}`
    end

    
    def exec_gconf_unset(variable_name)
      `#{GCONFTOOL} --unset #{APP_DIR + "/" + variable_name}`
    end





    ##
    ## GCONFTOOL LOAD RECURSIVE...
    ##

    # Since the ruby library 'gconf2' is deprecated, we call the
    # 'gconftool' executable.  Doing so one --get at a time is slow,
    # so we use --recursive-list to get everything at once.
    def load_alexandria_settings 
      all_vals = `#{GCONFTOOL} --recursive-list #{APP_DIR}`
      @alexandria_settings.merge!(gconftool_values_to_hash(all_vals))
    end


    # May be useful to pre-load these settings
    def load_system_settings
      load_url_handler_settingss
      load_http_proxy_settings
    end


    # Called at most once, by #web_browser or #email_client
    def load_url_handler_settings
      # /desktop/gnome/url-handlers/http
      http_handler_vars = `#{GCONFTOOL} --recursive-list #{URL_HANDLERS_DIR + "/http"}`
      http_handler = gconftool_values_to_hash(http_handler_vars)
      if http_handler['enabled']
        @http_command = http_handler['command']
      end

      mailto_handler_vars = `#{GCONFTOOL} --recursive-list #{URL_HANDLERS_DIR + "/mailto"}`
      mailto_handler = gconftool_values_to_hash(mailto_handler_vars)
      if mailto_handler['enabled']
        @mailto_command = mailto_handler['command']
      end
      @url_handlers_loaded = true
    end

    # Called at most once, by #http_proxy_config
    def load_http_proxy_settings
      http_proxy_vars = `#{GCONFTOOL} --recursive-list #{HTTP_PROXY_DIR}`
      http_proxy = gconftool_values_to_hash(http_proxy_vars)
      if http_proxy['use_http_proxy']
        proxy_mode = `#{GCONFTOOL} --get #{HTTP_PROXY_MODE}`.chomp
        if proxy_mode == "manual"
          @use_http_proxy = true
          @proxy_host = http_proxy['host']
          @proxy_port = http_proxy['port']
          @proxy_user = http_proxy['authentication_user']
          @proxy_password = http_proxy['authentication_n_password']
        end
      end
      @http_proxy_loaded = true
    end



    # 'gconftool -R' returns keys and values, one per line, with one
    # leading space, separated with " = " This method parses the keys
    # and values (guessing the type of the value using the
    # #discriminate method) and returns them in a Hash.
    def gconftool_values_to_hash(all_vals)
      hash = {}
      vals = all_vals.split(/$/)
      vals.each do |val|
        if /([a-z_]+) = (.*)/ =~ val
          hash[$1] = discriminate($2)
        end
      end
      hash
    end

    # Make a judgement about the type of the settings we get back from
    # gconftool. This is not fool-proof, but it *does* work for the
    # range of values used by Alexandria.
    def discriminate(value)
      if value == "true"        # bool
        return true
      elsif value == "false"    # bool 
        return false
      elsif value =~ /^[0-9]+$/   # int
        return value.to_i
      elsif value =~ /^\[(.*)\]$/ # list (assume of type String)
        return $1.split(",")
      elsif value =~ /^\((.*)\)$/ # pair (assume of type int)
        begin
          pair = $1.split(",")
          return [discriminate(pair.first), discriminate(pair.last)]
        rescue
          return [0,0]
        end
      else
        return value           # string
      end
    end

  end
end
