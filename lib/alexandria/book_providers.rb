# Copyright (C) 2004 Laurent Sansonetti
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

module Alexandria
    class BookProviders < Array
        include Singleton
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

		SEARCH_BY_ISBN, SEARCH_BY_TITLE, SEARCH_BY_AUTHORS, SEARCH_BY_KEYWORD = (0..3).to_a 

    	def self.search(criterion, type)
            self.instance.each do |factory|
                begin
                    if stuff = factory.search(criterion, type)
                        return stuff
                    end
                rescue TimeoutError
                    raise _("Couldn't reach the provider '%s': timeout expired.") % factory.name
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
                attr_reader :provider_name, :name, :description, :possible_values
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
                    Alexandria::Preferences.instance.send("#{provider_name}_#{name}=", new_value)
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
                    val = Alexandria::Preferences.instance.send("#{@provider_name}_#{var.name}")
                    var.value = val unless val.nil?
                end
            end
        end
       
        require 'alexandria/book_providers/amazon'
        require 'alexandria/book_providers/proxis'
       
        def initialize
            self.replace [ AmazonProvider, ProxisProvider ].map { |x| x.new }
        end

        def self.method_missing(id, *args, &block)
            self.instance.method(id).call(*args, &block)
        end
    end
end
