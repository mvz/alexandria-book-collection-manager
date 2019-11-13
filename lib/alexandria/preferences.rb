# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "singleton"
require "set"
require "alexandria/default_preferences"

module Alexandria
  class Preferences
    include Singleton
    include Logging

    APP_DIR = "/apps/alexandria"
    HTTP_PROXY_DIR = "/system/http_proxy"
    HTTP_PROXY_MODE = "/system/proxy/mode"
    URL_HANDLERS_DIR = "/desktop/gnome/url-handlers"

    GCONFTOOL = "gconftool-2"

    def initialize
      @alexandria_settings = {}
      @changed_settings = Set.new

      @url_handlers_loaded = false
      @http_command = nil
      @mailto_command = nil

      @http_proxy_loaded = false
      @use_http_proxy = false
      @proxy_host = nil
      @proxy_port = nil
      @proxy_user = nil
      @proxy_password = nil

      load_alexandria_settings
    end

    def http_proxy_config
      load_http_proxy_settings unless @http_proxy_loaded
      if @use_http_proxy && @proxy_host && @proxy_port
        [@proxy_host, @proxy_port, @proxy_user, @proxy_password]
      end
    end

    def save!
      log.debug { "preferences save!" }
      @changed_settings.each do |variable_name|
        log.debug { "saving preference #{variable_name} / #{@alexandria_settings[variable_name].class}" }
        generic_save_setting(variable_name, @alexandria_settings[variable_name])
      end
      @changed_settings.clear
    end

    def method_missing(id, *args)
      method = id.id2name
      if (match = /(.*)=$/.match(method))
        if args.length != 1
          raise "Set method #{method} should be called with " \
            "only one argument (was called with #{args.length})"
        end
        variable_name = match[1]
        new_value = args.first
        generic_setter(variable_name, new_value)
      else
        unless args.empty?
          raise "Get method #{method} should be called " \
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
      @changed_settings << variable_name unless new_value == old_value
    end

    def generic_save_setting(variable_name, new_value)
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
      elsif new_value.nil?
        exec_gconf_unset(variable_name)
      else
        # set non-list value
        exec_gconf_set(var_path, new_value)
      end
    rescue StandardError => ex
      log.debug { new_value.inspect }
      log.error { "Could not set GConf setting #{variable_name} to value: #{new_value.inspect}" }
      log << ex.message
      log << ex
    end

    ##
    ## GCONFTOOL SET and SET LIST and SET PAIR and UNSET
    ##

    def get_gconf_type(value)
      if value.is_a?(String)
        "string"
      elsif value.is_a?(Integer)
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
      if list_type == "int" && new_list.size == 2
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
      list.map! { |x| x.gsub(/\"/, '\\"') } if get_gconf_type(list.first) == "string"
      contents = list.join(",")
      "[" + contents + "]"
    end

    def exec_gconf_set(var_path, new_value)
      if /cols_width/.match?(var_path)
        puts new_value

        # new_value = {}
      end
      type = get_gconf_type(new_value)
      value_str = new_value
      if new_value.is_a? String
        new_value = new_value.gsub(/\"/, '\\"')
        value_str = "\"#{new_value}\""
      end
      puts value_str if /cols_width/.match?(var_path)
      `gconftool-2 --type #{type} --set #{var_path} #{value_str}`
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

    # Called at most once, by #http_proxy_config
    # TODO: Enforce this.
    def load_http_proxy_settings
      http_proxy_vars = `#{GCONFTOOL} --recursive-list #{HTTP_PROXY_DIR}`
      http_proxy = gconftool_values_to_hash(http_proxy_vars)
      if http_proxy["use_http_proxy"]
        proxy_mode = `#{GCONFTOOL} --get #{HTTP_PROXY_MODE}`.chomp
        if proxy_mode == "manual"
          @use_http_proxy = true
          @proxy_host = http_proxy["host"]
          @proxy_port = http_proxy["port"]
          @proxy_user = http_proxy["authentication_user"]
          @proxy_password = http_proxy["authentication_n_password"]
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
        hash[Regexp.last_match[1]] = discriminate(Regexp.last_match[2]) if /([a-z_]+) = (.*)/ =~ val
      end
      hash
    end

    # Make a judgement about the type of the settings we get back from
    # gconftool. This is not fool-proof, but it *does* work for the
    # range of values used by Alexandria.
    def discriminate(value)
      if value == "true"        # bool
        true
      elsif value == "false"    # bool
        false
      elsif /^[0-9]+$/.match?(value) # int
        value.to_i
      elsif value =~ /^\[(.*)\]$/ # list (assume of type String)
        Regexp.last_match[1].split(",")
      elsif value =~ /^\((.*)\)$/ # pair (assume of type int)
        begin
          pair = Regexp.last_match[1].split(",")
          return [discriminate(pair.first), discriminate(pair.last)]
        rescue StandardError
          return [0, 0]
        end
      else
        value # string
      end
    end
  end
end
