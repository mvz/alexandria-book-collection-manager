# Copyright (C) 2004-2005 Laurent Sansonetti
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
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

require 'singleton'

module Alexandria
    class BookProviders < Array
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
                return factory.search(criterion, type)
            rescue Exception => boom
                if self.last == factory
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
            def initialize(provider_name)
                @provider_name = provider_name
            end

            class Variable
                attr_reader :provider_name, :name, :description, 
                            :possible_values
                attr_accessor :value
            
                def initialize(provider_name, name, description, default_value,
                               possible_values=nil)

                    @provider_name = provider_name
                    @name = name
                    @description = description
                    @value = default_value
                    @possible_values = possible_values
                end

                def new_value=(new_value)
                    message = "#{provider_name}_#{name}="
                    Alexandria::Preferences.instance.send(message, new_value)
                    self.value = new_value
                end
            end
            
            def add(*args)
                self << Variable.new(@provider_name, *args) 
            end
            
            def [](obj)
                case obj
                    when String
                        var = self.find { |var| var.name == obj }
                        var ? var.value : nil
                    when Integer
                        old_idx(obj)
                end
            end
            alias_method :old_idx, :[]
            
            def read
                self.each do |var|
                    message = "#{@provider_name}_#{var.name}"
                    val = Alexandria::Preferences.instance.send(message)
                    var.value = val unless val.nil?
                end
            end
        end
      
        class GenericProvider
            attr_reader :name, :fullname, :prefs
            include Singleton

            def initialize(name, fullname=nil)
                @name = name 
                @fullname = (fullname or name)
                @prefs = Preferences.new(name.downcase)
            end
            
            def transport
                if config = Alexandria::Preferences.instance.http_proxy_config
                    Net::HTTP.Proxy(*config)
                else
                    Net::HTTP
                end
            end
        end
 
        require 'alexandria/book_providers/amazon'
        require 'alexandria/book_providers/bn'
        require 'alexandria/book_providers/proxis'
        require 'alexandria/book_providers/mcu'
       
        def initialize
            @prefs = Alexandria::Preferences.instance
            update_priority
        end

        def update_priority
            providers = {}
            self.class.constants.each do |constant|
                next unless md = /(.+)Provider$/.match(constant)
                klass = self.class.module_eval(constant)
                if klass.superclass == GenericProvider
                    providers[md[1]] = klass.instance
                end
            end
            self.clear
            priority = (@prefs.providers_priority or [])
            priority.map! { |x| x.strip }
            rest = providers.keys - priority
            priority.each { |pname| self << providers[pname] }
            rest.sort.each { |pname| self << providers[pname] }
        end

        def self.method_missing(id, *args, &block)
            self.instance.method(id).call(*args, &block)
        end
    end
end
