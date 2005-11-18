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

module Alexandria
    class SmartLibrary < Array
        attr_accessor :rules, :libraries, :name

        ALL_RULES, ANY_RULE = 1, 2
        attr_accessor :predicate_operator_rule

        class Rule
            include GetText
            extend GetText
            bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

            class Operand < Struct.new(:book_selector, :name, :klass)
                def <=>(x)
                    self.name <=> x.name
                end
            end

            class Operator < Struct.new(:name, :proc, :proc_args_count)
                def <=>(x)
                    self.name <=> x.name
                end

                def proc_args_count
                    (count = super) == nil ? 1 : count
                end
            end

            LEFT_OPERANDS = [
                Operand.new(:title, _("Title"), String),
                Operand.new(:isbn, _("ISBN"), String),
                Operand.new(:authors, _("Authors"), String),
                Operand.new(:publisher, _("Publisher"), String),
                Operand.new(:publish_year, _("Publish Year"), Integer),
                Operand.new(:edition, _("Binding"), String),
                Operand.new(:rating, _("Rating"), Integer),
                Operand.new(:notes, _("Notes"), String),
                Operand.new(:loaned, _("Loaning State"), TrueClass),
                Operand.new(:loaned_since, _("Loaning Date"), Time),
                Operand.new(:loaned_to, _("Loaning Person"), String)
            ].sort

            attr_reader :left_operand

            module Operators
                include GetText
                extend GetText
                bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

                IS_TRUE = Operator.new(_("is set"), proc { |x| x }, 0)
                IS_NOT_TRUE = Operator.new(_("is not set"), proc { |x| !x }, 0)
                IS = Operator.new(_("is"), proc { |x, y| x == y })
                IS_NOT = Operator.new(_("is not"), proc { |x, y| x != y })
                CONTAINS = Operator.new(_("contains"), 
                                        proc { |x, y| x.include?(y) })
                DOES_NOT_CONTAIN = Operator.new(_("does not contain"), 
                                                proc { |x, y| !x.include?(y) })
                STARTS_WITH = Operator.new(_("starts with"),
                                           proc { |x, y| /^#{y}/.match(x) })
                ENDS_WITH = Operator.new(_("ends with"),
                                         proc { |x, y| /#{y}$/.match(x) })
                IS_GREATER_THAN = Operator.new(_("is greater than"),
                                               proc { |x, y| x > y })
                IS_LESS_THAN = Operator.new(_("is less than"),
                                            proc { |x, y| x < y })
                IS_AFTER = Operator.new(_("is after"), IS_GREATER_THAN.proc)
                IS_BEFORE = Operator.new(_("is before"), IS_LESS_THAN.proc)
                IS_IN_LAST = Operator.new(_("is in last"),
                                          proc { |x, y| Time.now - x <= 
                                                        3600*24*y })
                IS_NOT_IN_LAST = Operator.new(_("is not in last"),
                                              proc { |x, y| Time.now - x > 
                                                            3600*24*y })
            end

            BOOLEAN_OPERATORS = [ 
                Operators::IS_TRUE, 
                Operators::IS_NOT_TRUE
            ].sort

            STRING_OPERATORS = [
                Operators::IS,
                Operators::IS_NOT,
                Operators::CONTAINS,
                Operators::DOES_NOT_CONTAIN,
                Operators::STARTS_WITH,
                Operators::ENDS_WITH
            ].sort
   
            INTEGER_OPERATORS = [
                Operators::IS, 
                Operators::IS_NOT, 
                Operators::IS_GREATER_THAN, 
                Operators::IS_LESS_THAN
            ].sort

            TIME_OPERATORS = [
                Operators::IS,
                Operators::IS_NOT,
                Operators::IS_AFTER, 
                Operators::IS_BEFORE, 
                Operators::IS_IN_LAST, 
                Operators::IS_NOT_IN_LAST
            ].sort
 
            def left_operand=(operand)
                return if @left_operand != nil and 
                    @left_operand.book_selector == operand.book_selector
                
                @left_operand = operand
            end

            def self.operators_for_operand(operand)
                case operand.klass.name
                    when 'String'
                        STRING_OPERATORS
                    when 'Integer'
                        INTEGER_OPERATORS
                    when 'TrueClass'
                        BOOLEAN_OPERATORS
                    when 'Time'
                        TIME_OPERATORS
                    else
                        raise "invalid operand klass #{operand.klass}"
                end
            end

            def filter_proc(operator, value)
                proc do |book|
                    left_value = book.send(@left_operator.book_selector)
                    operator.proc.call(left_value, value)
                end
            end
        end

        def refilter
            raise "need libraries" if @libraries.nil? or @libraries.empty?
            raise "need predicate operator" if @predicate_operator_rule.nil?
            raise "need rule" if @rules.nil? or @rules.empty? 

            filters = @rules.map { |x| x.filter_proc }
            selector = @predicate_operator_rule == ALL_RULES ? :all? : :any?

            self.clear
            
            @libraries.each do |library| 
                filtered_library = library.select do |book|
                    filters.send(selector) { |filter| filter.call(book) }
                end
                self.concat(filtered_library)
            end
        end 
    end
end
