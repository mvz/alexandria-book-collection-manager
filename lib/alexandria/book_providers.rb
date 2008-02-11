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

module Alexandria
  class BookProviders < Array
    include Logging
    include Singleton
    include GetText
    GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

    SEARCH_BY_ISBN, SEARCH_BY_TITLE, SEARCH_BY_AUTHORS,
    SEARCH_BY_KEYWORD = (0..3).to_a

    class SearchError < StandardError; end
    class NoResultsError < SearchError; end
    class TooManyResultsError < SearchError; end
    class InvalidSearchTypeError < SearchError; end

    def self.search(criterion, type)
      factory_n = 0
      begin
        factory = self.instance[factory_n]
        puts factory.fullname + " lookup" if $DEBUG
        results = factory.search(criterion, type)

        if results.length == 0
          raise NoResultsError
        else
          puts "found at " + factory.fullname
          return results
        end
      rescue Exception => boom
        if self.last == factory
          puts "Error while searching #{criterion}"
          raise case boom
                when Timeout::Error
                  _("Couldn't reach the provider '%s': timeout " +
                    "expired.") % factory.name

                when SocketError
                  _("Couldn't reach the provider '%s': socket " +
                    "error (%s).") % [factory.name, boom.message]

                when NoResultsError
                  _("No results were found.  Make sure your " +
                    "search criterion is spelled correctly, and " +
                    "try again.")

                when TooManyResultsError
                  _("Too many results for that search.")

                when InvalidSearchTypeError
                  _("Invalid search type.")

                else
                  boom.message
                end
        else
          factory_n += 1
          retry
        end
      end
    end

    def self.isbn_search(criterion)
      self.search(criterion, SEARCH_BY_ISBN)
    end

    class Preferences < Array
      def initialize(provider)
        @provider = provider
      end

      class Variable
        attr_reader :provider_name, :name, :description,
        :possible_values
        attr_accessor :value

        def initialize(provider, name, description, default_value,
                       possible_values=nil, mandatory=true)

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
          message = @provider.variable_name(self) + '='
          Alexandria::Preferences.instance.send(message,
                                                new_value)
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
        self.find { |var| var.name == name }
      end

      def read
        self.each do |var|
          message = @provider.variable_name(var)
          val = Alexandria::Preferences.instance.send(message)
          var.value = val unless (val.nil? or (val == "" and var.mandatory?))
        end
      end
    end

    class AbstractProvider
      attr_reader :prefs
      attr_accessor :name, :fullname

      def initialize(name, fullname=nil)
        @name = name
        @fullname = (fullname or name)
        @prefs = Preferences.new(self)
      end

      def reinitialize(fullname)
        @name << '_' << fullname.hash.to_s
        @fullname = fullname
        prefs = Alexandria::Preferences.instance
        ary = prefs.abstract_providers
        ary ||= []
        ary << @name
        prefs.abstract_providers = ary
        message = variable_name('name') + '='
        prefs.send(message, @fullname)
      end

      def remove
        prefs = Alexandria::Preferences.instance
        if ary = prefs.abstract_providers
          ary.delete(@name)
          prefs.abstract_providers = ary
        end
        if ary = prefs.providers_priority and ary.include?(@name)
          ary.delete(@name)
          prefs.providers_priority = ary
        end
        self.prefs.each do |variable|
          name = variable_name(variable)
          prefs.remove_preference(name)
        end
        name = variable_name('name')
        prefs.remove_preference(name)
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
        @name.downcase + '_' + s
      end

      def transport
        config = Alexandria::Preferences.instance.http_proxy_config
        config ? Net::HTTP.Proxy(*config) : Net::HTTP
      end

      def abstract?
        self.class.abstract?
      end

      def self.abstract?
        (not self.included_modules.include?(Singleton))
      end

      def <=>(provider)
        self.fullname <=> provider.fullname
      end

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

    require 'alexandria/book_providers/bn'
    require 'alexandria/book_providers/proxis'
    require 'alexandria/book_providers/mcu'
    require 'alexandria/book_providers/thalia'
    require 'alexandria/book_providers/ibs_it'
    require 'alexandria/book_providers/renaud'
    require 'alexandria/book_providers/adlibris'
    require 'alexandria/book_providers/ls'
    require 'alexandria/book_providers/bol_it'
    require 'alexandria/book_providers/webster_it'
    require 'alexandria/book_providers/worldcat'

    begin
      require 'alexandria/book_providers/amazon'
    rescue LoadError
      log.info { "Can't load Ruby/Amazon, hence provider Amazon not available" }
    end

    # mechanize is optional
    begin
      require 'alexandria/book_providers/dea_store_it'
    rescue LoadError
      log.info { "Can't load mechanize, hence provider Deastore not available" }
    end

    # Ruby/ZOOM is optional
    begin
      require 'alexandria/book_providers/z3950'
    rescue LoadError
      log.info { "Can't load Ruby/ZOOM, hence Z39.50 and providers Library of Congress, British Library not available" }
    end

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
        next unless md = /(.+)Provider$/.match(constant)
        klass = self.class.module_eval(constant)
        if klass.ancestors.include?(AbstractProvider) and
            klass != GenericProvider and
            klass != AbstractProvider

          if klass.abstract?
            @abstract_classes << klass
          else
            providers[md[1]] = klass.instance
          end
        end
      end
      if ary = @prefs.abstract_providers
        ary.each do |name|
          md = /^(.+)_/.match(name)
          next unless md
          klass_name = md[1] + 'Provider'
          klass = @abstract_classes.find { |x| x.name.include?(klass_name) }
          next unless klass
          fullname = @prefs.send(name.downcase + '_name')
          next unless fullname
          instance = klass.new
          instance.name = name
          instance.fullname = fullname
          instance.prefs.read
          providers[name] = instance
        end
      end
      self.clear
      priority = (@prefs.providers_priority or [])
      priority.map! { |x| x.strip }
      rest = providers.keys - priority
      priority.each { |pname| self << providers[pname] }
      rest.sort.each { |pname| self << providers[pname] }
      self.compact!
    end

    def self.method_missing(id, *args, &block)
      self.instance.method(id).call(*args, &block)
    end
  end
end
