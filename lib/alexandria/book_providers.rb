# frozen_string_literal: true

# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2009 Cathal Mc Ginley
# Copyright (C) 2011, 2014 Matijs van Zuijlen
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

require "singleton"
require "observer"

module Alexandria
  # FIXME: Use delegation instead of inheritance.
  class BookProviders < Array
    include Logging
    include Singleton
    include Observable
    include GetText
    GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

    SEARCH_BY_ISBN, SEARCH_BY_TITLE, SEARCH_BY_AUTHORS,
    SEARCH_BY_KEYWORD = (0..3).to_a

    class SearchError < StandardError; end

    class NoResultsError < SearchError; end

    class TooManyResultsError < SearchError; end

    class InvalidSearchTypeError < SearchError; end

    # These errors are not really errors
    class ProviderSkippedError < NoResultsError; end

    class SearchEmptyError < SearchError; end

    def self.search(criterion, type)
      factory_n = 0

      begin
        factory = instance[factory_n]
        log.debug { factory.fullname + " lookup" }
        unless factory.enabled
          log.debug { factory.fullname + " disabled!, skipping..." }
          raise ProviderSkippedError
        end
        instance.changed
        instance.notify_observers(:searching, factory.fullname) # new
        results = factory.search(criterion, type)

        # sanity check if at least one valid result is actually found
        results.delete_if { |book, _cover| book.nil? }

        if results.empty?
          instance.changed
          instance.notify_observers(:not_found, factory.fullname) # new
          raise NoResultsError
        else
          log.info { "found at " + factory.fullname }
          instance.changed
          instance.notify_observers(:found, factory.fullname) # new
          results
        end
      rescue StandardError => ex
        if ex.is_a? NoResultsError
          unless ex.instance_of? ProviderSkippedError
            instance.changed
            instance.notify_observers(:not_found, factory.fullname) # new
            Thread.new { sleep(0.5) }.join
          end
        else
          instance.changed
          instance.notify_observers(:error, factory.fullname) # new
          Thread.new { sleep(0.5) }.join # hrmmmm, to make readable...
          trace = ex.backtrace.join("\n >")
          log.warn { "Provider #{factory.name} encountered error: #{ex.message} #{trace}" }
        end
        if factory == instance.last
          log.warn { "Error while searching #{criterion}" }
          message = case ex
                    when Timeout::Error
                      _("Couldn't reach the provider '%s': timeout " \
                        "expired.") % factory.name

                    when SocketError
                      format(_("Couldn't reach the provider '%s': socket " \
                        "error (%s)."), factory.name, ex.message)

                    when NoResultsError, ProviderSkippedError
                      _("No results were found.  Make sure your " \
                        "search criterion is spelled correctly, and " \
                        "try again.")

                    when TooManyResultsError
                      _("Too many results for that search.")

                    when InvalidSearchTypeError
                      _("Invalid search type.")

                    else
                      ex.message
                    end
          log.debug { "raising empty error #{message}" }
          raise SearchEmptyError, message # rubocop:disable I18n/GetText/DecorateFunctionMessage
        else
          factory_n += 1
          retry
        end
      end
    end

    def self.isbn_search(criterion)
      search(criterion, SEARCH_BY_ISBN)
    end

    class Preferences < Array
      def initialize(provider)
        @provider = provider
      end

      class Variable
        attr_reader :name, :description,
                    :possible_values
        attr_accessor :value

        def initialize(provider, name, description, default_value,
                       possible_values = nil, mandatory = true)

          @provider = provider
          @name = name
          @description = description
          @value = default_value
          @possible_values = possible_values
          @mandatory = mandatory
        end

        def default_value=(new_value)
          self.value = new_value
        end

        def new_value=(new_value)
          name = @provider.variable_name(self)
          Alexandria::Preferences.instance.set_variable(name, new_value)
          self.value = new_value
        end

        def provider_name
          @provider.name.downcase
        end

        def mandatory?
          @mandatory
        end
      end

      def add(*args)
        self << Variable.new(@provider, *args)
      end

      def [](obj)
        case obj
        when String
          var = variable_named(obj)
          var ? var.value : nil
        when Integer
          super(obj)
        end
      end

      def variable_named(name)
        find { |var| var.name == name }
      end

      def read
        each do |var|
          name = @provider.variable_name(var)
          val = Alexandria::Preferences.instance.get_variable(name)
          var.value = val unless val.nil? || ((val == "") && var.mandatory?)
        end
      end
    end

    class AbstractProvider
      include GetText
      attr_reader :prefs
      attr_accessor :name, :fullname

      def initialize(name, fullname = nil)
        @name = name
        @fullname = (fullname || name)
        @prefs = Preferences.new(self)
        @prefs.add("enabled", _("Enabled"), true, [true, false])
      end

      def enabled
        @prefs["enabled"]
      end

      def toggle_enabled
        old_value = enabled
        @prefs.variable_named("enabled").new_value = !old_value
      end

      def reinitialize(fullname)
        @name = "#{name}_#{fullname.hash}"
        @fullname = fullname
        prefs = Alexandria::Preferences.instance
        ary = prefs.get_variable :abstract_providers
        ary ||= []
        ary << @name
        prefs.set_variable :abstract_providers, ary
        message = variable_name("name")
        prefs.set_variable(message, @fullname)
      end

      def remove
        prefs = Alexandria::Preferences.instance
        if (ary = prefs.get_variable :abstract_providers)
          ary.delete(@name)
          prefs.set_variable :abstract_providers, ary
        end
        if (ary = prefs.providers_priority) && ary.include?(@name)
          ary.delete(@name)
          prefs.providers_priority = ary
        end
        self.prefs.each do |variable|
          name = variable_name(variable)
          prefs.remove_preference(name)
        end
        name = variable_name("name")
        prefs.remove_preference(name)
        prefs.save!
      end

      def variable_name(object)
        s = case object
            when String
              object
            when Preferences::Variable
              object.name
            else
              raise
            end
        @name.downcase + "_" + s
      end

      def transport
        config = Alexandria::Preferences.instance.http_proxy_config
        config ? Net::HTTP.Proxy(*config) : Net::HTTP
      end

      def abstract?
        self.class.abstract?
      end

      def self.abstract?
        !included_modules.include?(Singleton)
      end

      def <=>(other)
        fullname <=> other.fullname
      end

      # FIXME: Clean up this complex abstract/concrete class system
      def self.unabstract
        include Singleton
        undef_method :reinitialize
        undef_method :name=
        undef_method :fullname=
        undef_method :remove
      end
    end

    class GenericProvider < AbstractProvider
      unabstract
    end

    require "alexandria/book_providers/douban" # only requires YAML

    # Amazon AWS (Amazon Associates Web Services) provider, needs hpricot
    require "alexandria/book_providers/amazon_aws"

    # Website based providers
    require "alexandria/book_providers/adlibris"
    require "alexandria/book_providers/barnes_and_noble"
    require "alexandria/book_providers/proxis"
    require "alexandria/book_providers/siciliano"
    require "alexandria/book_providers/thalia_provider"
    require "alexandria/book_providers/worldcat"

    # Z39.50 based providers
    require "alexandria/book_providers/z3950"

    attr_reader :abstract_classes

    def initialize
      @prefs = Alexandria::Preferences.instance
      @abstract_classes = []
      update_priority
    end

    def update_priority
      # This is weird code that sorts through the list of classes brought
      # in by requires and sorts through whether they are 'Abstract' or not,
      # adding their names to @prefs.

      @abstract_classes.clear
      providers = {}
      self.class.constants.each do |constant|
        md = /(.+)Provider$/.match(constant)
        next unless md

        klass = self.class.module_eval(constant.to_s)
        if klass < AbstractProvider &&
            (klass != GenericProvider) &&
            (klass != WebsiteBasedProvider)

          if klass.abstract?
            @abstract_classes << klass
          else
            providers[md[1]] = klass.instance
          end
        end
      end
      if (ary = @prefs.get_variable :abstract_providers)
        ary.each do |name|
          md = /^(.+)_/.match(name)
          next unless md

          klass_name = md[1] + "Provider"
          klass = @abstract_classes.find { |x| x.name.include?(klass_name) }
          next unless klass

          fullname = @prefs.send(name.downcase + "_name")
          next unless fullname

          instance = klass.new
          instance.name = name
          instance.fullname = fullname
          instance.prefs.read
          providers[name] = instance
        end
      end
      clear
      rejig_providers_priority
      priority = (@prefs.providers_priority || [])
      priority.map!(&:strip)
      rest = providers.keys - priority
      priority.each { |pname| self << providers[pname] }
      rest.sort.each { |pname| self << providers[pname] }
      compact!
    end

    def self.list
      instance
    end

    def self.abstract_classes
      instance.abstract_classes
    end

    private

    def rejig_providers_priority
      priority = (@prefs.providers_priority || [])
      return if priority.empty?

      changed = false

      if (ecs_index = priority.index("AmazonECS"))
        priority[ecs_index] = "Amazon" # replace legacy "AmazonECS" name
        priority.uniq! # remove any other "Amazon" from the list
        changed = true
      end
      if (worldcat_index = priority.index("Worldcat"))
        priority[worldcat_index] = "WorldCat"
        changed = true
      end
      if (adlibris_index = priority.index("Adlibris"))
        priority[adlibris_index] = "AdLibris"
        changed = true
      end
      @prefs.providers_priority = priority if changed
    end
  end
end
