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

# require 'date'
require 'time'

module Alexandria
  class SmartLibrary < Array
    include Logging
    include GetText
    extend GetText
    bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

    ALL_RULES, ANY_RULE = 1, 2
    attr_reader :name
    attr_accessor :rules, :predicate_operator_rule, :deleted_books

    DIR = File.join(ENV['HOME'], '.alexandria', '.smart_libraries')
    EXT = '.yaml'

    def initialize(name, rules, predicate_operator_rule)
      super()
      raise if name.nil? or rules.nil? or predicate_operator_rule.nil?
      @name = name
      @rules = rules
      @predicate_operator_rule = predicate_operator_rule
      save
      libraries = Libraries.instance
      libraries.add_observer(self)
      self.libraries = libraries.all_regular_libraries
      #carry deleted books over from libraries that are part of the smart library
      self.deleted_books=libraries.deleted_books
      @cache = {}
    end

    def self.loadall
      a = []
      begin
        # Deserialize smart libraries.
        Dir.chdir(DIR) do
          Dir["*" + EXT].each do |filename|
            # Skip non-regular files.
            next unless File.stat(filename).file?

            text = IO.read(filename)
            hash = YAML.load(text)
            begin
              smart_library = self.from_hash(hash)
              a << smart_library
            rescue => e
              puts "Cannot load serialized smart library: #{e}"
              puts e.backtrace
            end
          end
        end

      rescue Errno::ENOENT
        # First run and no smart libraries yet? Provide some default
        # ones.
        self.sample_smart_libraries.each do |smart_library|
          smart_library.save
          a << smart_library
        end
      end
      a.each { |x| x.refilter }
      return a
    end

    def self.sample_smart_libraries
      a = []

      operands = Rule::Operands::LEFT

      # Favorite books.
      rule = Rule.new(operands.find { |x| x.book_selector == :rating },
                      Rule::Operators::IS,
                      UI::MainApp::MAX_RATING_STARS.to_s)
      a << self.new(_("Favorite"), [rule], ALL_RULES)

      # Loaned books.
      rule = Rule.new(operands.find { |x| x.book_selector == :loaned },
                      Rule::Operators::IS_TRUE,
                      nil)
      a << self.new(_("Loaned"), [rule], ALL_RULES)

      #Redd books.
      rule = Rule.new(operands.find { |x| x.book_selector == :redd },
                      Rule::Operators::IS_TRUE,
                      nil)
      a << self.new(_("Read"), [rule], ALL_RULES)

      #Own books.
      rule = Rule.new(operands.find { |x| x.book_selector == :own },
                      Rule::Operators::IS_TRUE,
                      nil)
      a << self.new(_("Owned"), [rule], ALL_RULES)

      #Want books.
      rule = Rule.new(operands.find { |x| x.book_selector == :want },
                      Rule::Operators::IS_TRUE,
                      nil)
      rule2 = Rule.new(operands.find { |x| x.book_selector == :own },
                       Rule::Operators::IS_NOT_TRUE,
                       nil)
      a << self.new(_("Wishlist"), [rule, rule2], ALL_RULES)


      return a
    end

    def self.from_hash(hash)
      SmartLibrary.new(hash[:name],
                       hash[:rules].map { |x| Rule.from_hash(x) },
                       hash[:predicate_operator_rule] == :all \
                       ? ALL_RULES : ANY_RULE)
    end

    def to_hash
      {
        :name => @name,
        :predicate_operator_rule =>
        @predicate_operator_rule == ALL_RULES ? :all : :any,
        :rules => @rules.map { |x| x.to_hash }
      }
    end

    def name=(new_name)
      if @name != new_name
        old_yaml = self.yaml
        @name = new_name
        FileUtils.mv(old_yaml, self.yaml)
        save
      end
    end

    def update(*params)
      if params.first.is_a?(Libraries)
        libraries, action, library = params
        unless library.is_a?(self.class)
          self.libraries = libraries.all_libraries
          refilter
        end
      elsif params.first.is_a?(Library)
        refilter
      end
    end

    def refilter
      raise "need libraries" if @libraries.nil?
      raise "no libraries" if @libraries.empty?
      raise "need predicate operator" if @predicate_operator_rule.nil?
      raise "need rule" if @rules.nil? or @rules.empty?

      filters = @rules.map { |x| x.filter_proc }
      selector = @predicate_operator_rule == ALL_RULES ? :all? : :any?

      self.clear
      @cache.clear

      @libraries.each do |library|
        filtered_library = library.select do |book|
          filters.send(selector) { |filter| filter.call(book) } #Problem here.
        end
        filtered_library.each { |x| @cache[x] = library }
        self.concat(filtered_library)
      end
      @n_rated = select { |x| !x.rating.nil? and x.rating > 0 }.length
    end

    def cover(book)
      @cache[book].cover(book)
    end

    def yaml(book=nil)
      if book
        @cache[book].yaml(book)
      else
        File.join(DIR, @name + EXT)
      end
    end

    def save(book=nil)
      if book
        @cache[book].save(book)
      else
        FileUtils.mkdir_p(DIR)
        File.open(self.yaml, "w") { |io| io.puts self.to_hash.to_yaml }
      end
    end

    def save_cover(book, cover_uri)
      @cache[book].save_cover(book)
    end

    def cover(book)
      @cache[book].cover(book)
    end

    def final_cover(book)
      @cache[book].final_cover(book)
    end

    def copy_covers(somewhere)
      FileUtils.rm_rf(somewhere) if File.exists?(somewhere)
      FileUtils.mkdir(somewhere)
      each do |book|
        library = @cache[book]
        next unless File.exists?(library.cover(book))
        FileUtils.cp(File.join(library.path,
                               book.ident + Library::EXT[:cover]),
                     File.join(somewhere,
                               library.final_cover(book)))
      end
    end

    def n_rated
      @n_rated
    end

    def n_unrated
      length - n_rated
    end

    def ==(object)
      object.is_a?(self.class) && object.name == self.name
    end

    @@deleted_libraries = []

    def self.deleted_libraries
      @@deleted_libraries
    end

    def self.really_delete_deleted_libraries
      @@deleted_libraries.each do |library|
        puts "Deleting smart library file (#{self.yaml})" if $DEBUG
        FileUtils.rm_rf(library.yaml)
      end
    end

    def delete
      if @@deleted_libraries.include?(self)
        puts "Already deleted a SmartLibrary with this name"
        puts "(this might mess up undeletes...)"
        FileUtils.rm_rf(self.yaml)
        # so we just delete the old smart library, and 
        # 'pending' delete the new one of the same name...
        # urrr... yeah, that'll work!
      end
      @@deleted_libraries << self
    end

    def deleted?
      @@deleted_libraries.include?(self)
    end

    def undelete
      raise unless @@deleted_libraries.include?(self)
      @@deleted_libraries.delete(self)
    end

    #######
    private
    #######

    def libraries=(ary)
      @libraries.each { |x| x.delete_observer(self) } if @libraries
      @libraries = ary.select { |x| x.is_a?(Library) }
      @libraries.each { |x| x.add_observer(self) }
    end

    ######
    public
    ######

    class Rule
      include GetText
      extend GetText
      bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      attr_accessor :operand, :operation, :value

      def initialize(operand, operation, value)
        raise if operand.nil? or operation.nil? # value can be nil
        @operand = operand
        @operation = operation
        @value = value
      end

      def self.from_hash(hash)
        operand = Operands::LEFT.find do |x|
          x.book_selector == hash[:operand]
        end
        operator = Operators::ALL.find do |x|
          x.sym == hash[:operation]
        end
        Rule.new(operand, operator, hash[:value])
      end

      def to_hash
        {
          :operand => @operand.book_selector,
          :operation => @operation.sym,
          :value => @value
        }
      end

      class Operand < Struct.new(:name, :klass)
        def <=>(x)
          self.name <=> x.name
        end
      end

      class LeftOperand < Operand
        attr_accessor :book_selector

        def initialize(book_selector, *args)
          super(*args)
          @book_selector = book_selector
        end
      end

      class Operator < Struct.new(:sym, :name, :proc)
        def <=>(x)
          self.name <=> x.name
        end
      end

      module Operands
        include GetText
        extend GetText
        bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

        LEFT = [
                LeftOperand.new(:title, _("Title"), String),
                LeftOperand.new(:isbn, _("ISBN"), String),
                LeftOperand.new(:authors, _("Authors"), String),
                LeftOperand.new(:publisher, _("Publisher"), String),
                LeftOperand.new(:publishing_year, _("Publish Year"), Integer),
                LeftOperand.new(:edition, _("Binding"), String),
                LeftOperand.new(:rating, _("Rating"), Integer),
                LeftOperand.new(:notes, _("Notes"), String),
                LeftOperand.new(:tags, _("Tags"), Array),
                LeftOperand.new(:loaned, _("Loaning State"), TrueClass),
                LeftOperand.new(:loaned_since, _("Loaning Date"), Time),
                LeftOperand.new(:loaned_to, _("Loaning Person"), String),
                LeftOperand.new(:redd, _("Read"), TrueClass),
		LeftOperand.new(:redd_when, _("Date Read"), Time),
                LeftOperand.new(:own, _("Own"), TrueClass),
                LeftOperand.new(:want, _("Want"), TrueClass),
               ].sort

        STRING = Operand.new(nil, String)
        STRING_ARRAY = Operand.new(nil, String)
        INTEGER = Operand.new(nil, Integer)
        TIME = Operand.new(nil, Time)
        DAYS = Operand.new(_("days"), Integer)
      end

      module Operators
        include Logging
        include GetText
        extend GetText
        bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

        IS_TRUE = Operator.new(
                               :is_true,
                               _("is set"),
                               proc { |x| x })
        IS_NOT_TRUE = Operator.new(
                                   :is_not_true,
                                   _("is not set"),
                                   proc { |x| !x })
        IS = Operator.new(
                          :is,
                          _("is"),
                          proc { |x, y| x == y })
        IS_NOT = Operator.new(
                              :is_not,
                              _("is not"),
                              proc { |x, y| x != y })
        CONTAINS = Operator.new(
                                :contains,
                                _("contains"),
                                proc { |x, y| x.include?(y) })
        DOES_NOT_CONTAIN = Operator.new(
                                        :does_not_contain,
                                        _("does not contain"),
                                        proc { |x, y| !x.include?(y) })
        STARTS_WITH = Operator.new(
                                   :starts_with,
                                   _("starts with"),
                                   proc { |x, y| /^#{y}/.match(x) })
        ENDS_WITH = Operator.new(
                                 :ends_with,
                                 _("ends with"),
                                 proc { |x, y| /#{y}$/.match(x) })
        IS_GREATER_THAN = Operator.new(
                                       :is_greater_than,
                                       _("is greater than"),
                                       proc { |x, y| x > y })
        IS_LESS_THAN = Operator.new(
                                    :is_less_than,
                                    _("is less than"),
                                    proc { |x, y| x < y })
        IS_AFTER = Operator.new(
                                :is_after,
                                _("is after"),                              
				proc { |x, y| x.to_i > y.to_i and x!=nil })
        IS_BEFORE = Operator.new(
                                 :is_before,
                                 _("is before"),
                                 proc { |x, y| x.to_i < y.to_i and x!=nil})
        IS_IN_LAST = Operator.new(
                                  :is_in_last_days,
                                  _("is in last"),
                                  proc { |x, y|
                                    begin
                                      unless x.nil? or x.empty?
                                        log.debug { "Given Date: #{x.inspect} #{x.class}" }
                                        given_date = Time.parse(x)
                                        days = y.to_i * (24*60*60)
                                        
                                        Time.now - given_date <= days
                                      else
                                        false
                                      end
                                    rescue Exception => ex
                                      trace = ex.backtrace.join("\n >")
                                      log.warn { "Date matching failed #{ex} #{trace}" }
                                      false
                                    end
                                  })
        IS_NOT_IN_LAST = Operator.new(
                                      :is_not_in_last_days,
                                      _("is not in last"),
                                      proc { |x, y| 
begin
                                      unless x.nil? or x.empty?
                                        log.debug { "Given Date: #{x.inspect} #{x.class}" }
                                        given_date = Time.parse(x)
                                        days = y.to_i * (24*60*60)
                                        
                                        Time.now - given_date > days
                                      else
                                        false
                                      end
                                    rescue Exception => ex
                                      trace = ex.backtrace.join("\n >")
                                      log.warn { "Date matching failed #{ex} #{trace}" }
                                      false
                                    end



                                        #Time.now - x > 3600*24*y 

                                      })

        ALL = self.constants.map \
        { |x| self.module_eval(x) }.select \
        { |x| x.is_a?(Operator) }
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

      STRING_ARRAY_OPERATORS = [
                                Operators::CONTAINS,
                                Operators::DOES_NOT_CONTAIN
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

      def self.operations_for_operand(operand)
        case operand.klass.name
        when 'String'
          STRING_OPERATORS.map { |x| [x, Operands::STRING] }
        when 'Array'
          STRING_ARRAY_OPERATORS.map { |x| [x, Operands::STRING] }
        when 'Integer'
          INTEGER_OPERATORS.map { |x| [x, Operands::INTEGER] }
        when 'TrueClass'
          BOOLEAN_OPERATORS.map { |x| [x, nil] }
        when 'Time'
          TIME_OPERATORS.map do |x|
            if x == Operators::IS_IN_LAST or
                x == Operators::IS_NOT_IN_LAST

              [x, Operands::DAYS]
            else
              [x, Operands::TIME]
            end
          end
        else
          raise "invalid operand klass #{operand.klass}"
        end
      end

      def filter_proc
        proc do |book|
          begin
            left_value = book.send(@operand.book_selector)
          rescue => e
            puts e.message
          end
          right_value = @value
          if right_value.is_a?(String)
            left_value = left_value.to_s.downcase
            right_value = right_value.downcase
          end
          params = [left_value]
          params << right_value unless right_value.nil?
          @operation.proc.call(*params)
        end
      end
    end
  end
end
