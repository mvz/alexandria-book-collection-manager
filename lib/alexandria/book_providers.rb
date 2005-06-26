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
                results = factory.search(criterion, type)

                if results.length == 0
                    raise NoResultsError
                else
                    return results
                end
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
            def initialize(provider)
                @provider = provider
                @provider_name = provider.name.downcase
            end

            class Variable
                attr_reader :provider_name, :name, :description,
                            :possible_values
                attr_accessor :value

                def initialize(provider, name, description, default_value,
                               possible_values=nil)

                    @provider = provider
                    @provider_name = provider.name.downcase
                    @name = name
                    @description = description
                    @value = default_value
                    @possible_values = possible_values
                end

                def new_value=(new_value)
                    unless @provider.abstract?
                        message = "#{provider_name}_#{name}="
                        Alexandria::Preferences.instance.send(message,
                                                              new_value)
                    end
                    self.value = new_value
                end
            end

            def add(*args)
                self << Variable.new(@provider, *args)
            end

            def [](obj)
                p obj
                case obj
                    when String
                        var = self.find { |var| var.name == obj }
                        var ? var.value : nil
                    when Integer
                        super(obj)
                end
            end

            def read
                self.each do |var|
                    message = "#{@provider_name}_#{var.name}"
                    val = Alexandria::Preferences.instance.send(message)
                    var.value = val unless val.nil?
                end
            end
        end

        class AbstractProvider
            attr_reader :name, :fullname, :prefs

            def initialize(name, fullname=nil)
                @name = name
                @fullname = (fullname or name)
                @prefs = Preferences.new(self)
            end

            def reinitialize(fullname)
                @name << '_' << fullname.hash.to_s
                @fullname = fullname
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
        end

        class GenericProvider < AbstractProvider
            include Singleton
            undef_method :reinitialize
        end

        require 'alexandria/book_providers/amazon'
        require 'alexandria/book_providers/bn'
        require 'alexandria/book_providers/proxis'
        require 'alexandria/book_providers/mcu'
        require 'alexandria/book_providers/amadeus'
        require 'alexandria/book_providers/ibs_it'
        require 'alexandria/book_providers/z3950'

        attr_reader :abstract_classes

        def initialize
            @prefs = Alexandria::Preferences.instance
            @abstract_classes = []
            update_priority
        end

        def update_priority
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
