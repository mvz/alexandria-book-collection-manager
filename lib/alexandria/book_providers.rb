# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2009 Cathal Mc Ginley
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
require 'observer'
require 'alexandria/net'

module Alexandria
  class BookProviders < Array
    include Logging
    include Singleton
    include Observable
    include GetText
    GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

    SEARCH_BY_ISBN, SEARCH_BY_TITLE, SEARCH_BY_AUTHORS,
    SEARCH_BY_KEYWORD = (0..3).to_a

    class SearchError < StandardError; end
    class NoResultsError < SearchError; end
    class ProviderSkippedError < NoResultsError; end # not an error :^(
    class SearchEmptyError < SearchError; end # sigh, again not really an error
    class TooManyResultsError < SearchError; end
    class InvalidSearchTypeError < SearchError; end

    def self.search(criterion, type)
      factory_n = 0
      #puts "book_providers search #{self.instance.count_observers}"

      begin
        factory = self.instance[factory_n]
        puts factory.fullname + " lookup" if $DEBUG
        if (not factory.enabled)
          puts factory.fullname + " disabled!, skipping..." if $DEBUG
          raise ProviderSkippedError
        end
        self.instance.changed
        self.instance.notify_observers(:searching, factory.fullname) # new
        results = factory.search(criterion, type)

        # sanity check if at least one valid result is actually found
        results.delete_if { |book, cover| book.nil? }

        if results.length == 0
          self.instance.changed
          self.instance.notify_observers(:not_found, factory.fullname) # new
          raise NoResultsError
        else
          log.info { "found at " + factory.fullname }
          self.instance.changed
          self.instance.notify_observers(:found, factory.fullname) # new
          return results
        end
      rescue Exception => boom
        if boom.kind_of? NoResultsError
          unless boom.instance_of? ProviderSkippedError
            self.instance.changed
            self.instance.notify_observers(:not_found, factory.fullname) # new
            Thread.new {sleep(0.5)}.join
          end
        else        
          self.instance.changed
          self.instance.notify_observers(:error, factory.fullname) # new
          Thread.new {sleep(0.5)}.join # hrmmmm, to make readable...
          trace = boom.backtrace.join("\n >")
          log.warn { "Provider #{factory.name} encountered error: #{boom.message} #{trace}" }
        end
        if self.last == factory
          log.warn { "Error while searching #{criterion}" }
          message = case boom
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

                when ProviderSkippedError
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
          puts "raising empty error #{message}"
          raise SearchEmptyError, message
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
      include GetText
      attr_reader :prefs
      attr_accessor :name, :fullname

      def initialize(name, fullname=nil)
        @name = name
        @fullname = (fullname or name)
        @prefs = Preferences.new(self)
        @prefs.add("enabled", _("Enabled"), true, [true,false])
      end
      
      def enabled()
        @prefs['enabled']
      end
      
      def toggle_enabled()
        old_value = enabled()
        @prefs.variable_named('enabled').new_value = (not old_value)
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

    class WebsiteBasedProvider < GenericProvider
      # further defined in alexandria/book_providers/web.rb
      # its implementation requires Hpricot and HTMLEntities
    end

    require 'alexandria/book_providers/mcu' # yep, still mostly works !
    require 'alexandria/book_providers/douban' # only requires YAML

    #require 'alexandria/book_providers/ibs_it'
    #require 'alexandria/book_providers/renaud'
    #require 'alexandria/book_providers/bol_it'
    #require 'alexandria/book_providers/webster_it'
    log.info { "Not loading IBS, Renaud, BOL, Webster (providers not functional)" }



    # Amazon AWS (Amazon Associates Web Services) provider, needs hpricot
    begin
      begin
        require 'hpricot'
      rescue LoadError
        require 'rubygems'
        require 'hpricot'
      end
      require 'alexandria/book_providers/amazon_aws'
    rescue LoadError => ex
      log.error { ex }
      log.error { ex.backtrace.join("\n> ") }
      log.warn { "Can't load 'hpricot', hence Amazon book provider will not be available" }
    end

    
    # AdLibris (needs htmlentities and hpricot)
    begin
      begin
        require 'htmlentities'
        require 'hpricot'
      rescue LoadError
        require 'rubygems'
        require 'htmlentities'
        require 'hpricot'
      end
      
      require 'alexandria/book_providers/web'
      require 'alexandria/book_providers/adlibris'
      require 'alexandria/book_providers/barnes_and_noble'
      require 'alexandria/book_providers/deastore'
      require 'alexandria/book_providers/proxis'
      require 'alexandria/book_providers/siciliano'
      require 'alexandria/book_providers/thalia'
      require 'alexandria/book_providers/worldcat'

    rescue LoadError => ex
      log.warn { "Can't load 'hpricot' and 'htmlentities', hence AdLibris, Barnes & Noble, DeaStore, Proxis, Siciliano, Thalia and Worldcat book providers will not be available" }
    end


    # Ruby/ZOOM is optional
    begin
      begin
        require 'zoom'
        require 'marc'
      rescue LoadError
        require 'rubygems'
        require 'zoom'
        require 'marc'
      end
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
            klass != WebsiteBasedProvider and
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
      rejig_providers_priority()
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

    private

    def rejig_providers_priority
      priority = (@prefs.providers_priority or [])
      unless priority.empty?
        changed = false

        if ecs_index = priority.index("AmazonECS") 
          priority[ecs_index] = "Amazon" # replace legacy "AmazonECS" name
          priority.uniq! # remove any other "Amazon" from the list
          changed = true
        end
        if deastore_index = priority.index("DeaStore_it")
          priority[deastore_index] = "DeaStore"
          changed = true
        end
        if worldcat_index = priority.index("Worldcat")
          priority[worldcat_index] = "WorldCat"
          changed = true
        end
        if adlibris_index = priority.index("Adlibris")
          priority[adlibris_index] = "AdLibris"
          changed = true
        end
        @prefs.providers_priority = priority if changed
      end
    end

  end
end
