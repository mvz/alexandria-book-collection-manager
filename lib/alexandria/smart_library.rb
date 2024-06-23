# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

# require 'date'
require "time"

module Alexandria
  class SmartLibrary < Array
    include Logging
    include GetText
    extend GetText
    bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

    ALL_RULES = 1
    ANY_RULE = 2
    attr_reader :name, :n_rated
    attr_accessor :rules, :predicate_operator_rule, :deleted_books

    EXT = ".yaml"

    def initialize(name, rules, predicate_operator_rule, store = nil)
      super()
      raise if name.nil? || rules.nil? || predicate_operator_rule.nil?

      @name = name.dup.force_encoding("UTF-8")
      @rules = rules
      @predicate_operator_rule = predicate_operator_rule
      @store = store
      libraries = LibraryCollection.instance
      libraries.add_observer(self)
      self.libraries = libraries.all_regular_libraries
      # carry deleted books over from libraries that are part of the smart library
      self.deleted_books = libraries.deleted_books
      @cache = {}
    end

    def self.sample_smart_libraries(store)
      a = []

      operands = Rule::Operands::LEFT

      # Favorite books.
      rule = Rule.new(operands.find { |x| x.book_selector == :rating },
                      Rule::Operators::IS,
                      Book::MAX_RATING_STARS.to_s)
      a << new(_("Favorite"), [rule], ALL_RULES, store)

      # Loaned books.
      rule = Rule.new(operands.find { |x| x.book_selector == :loaned },
                      Rule::Operators::IS_TRUE,
                      nil)
      a << new(_("Loaned"), [rule], ALL_RULES, store)

      # Redd books.
      rule = Rule.new(operands.find { |x| x.book_selector == :redd },
                      Rule::Operators::IS_TRUE,
                      nil)
      a << new(_("Read"), [rule], ALL_RULES, store)

      # Own books.
      rule = Rule.new(operands.find { |x| x.book_selector == :own },
                      Rule::Operators::IS_TRUE,
                      nil)
      a << new(_("Owned"), [rule], ALL_RULES, store)

      # Want books.
      rule = Rule.new(operands.find { |x| x.book_selector == :want },
                      Rule::Operators::IS_TRUE,
                      nil)
      rule2 = Rule.new(operands.find { |x| x.book_selector == :own },
                       Rule::Operators::IS_NOT_TRUE,
                       nil)
      a << new(_("Wishlist"), [rule, rule2], ALL_RULES, store)

      a
    end

    def self.from_hash(hash, store)
      SmartLibrary.new(hash[:name],
                       hash[:rules].map { |x| Rule.from_hash(x) },
                       hash[:predicate_operator_rule] == :all ? ALL_RULES : ANY_RULE,
                       store)
    end

    def to_hash
      {
        name: @name,
        predicate_operator_rule: @predicate_operator_rule == ALL_RULES ? :all : :any,
        rules: @rules.map(&:to_hash)
      }
    end

    def name=(new_name)
      return unless @name != new_name

      old_yaml = yaml
      @name = new_name
      FileUtils.mv(old_yaml, yaml)
      save
    end

    def update(*params)
      case params.first
      when LibraryCollection
        libraries, _, library = params
        unless library.is_a?(self.class)
          self.libraries = libraries.all_libraries
          refilter
        end
      when Library
        refilter
      end
    end

    def refilter
      filters = @rules.map(&:filter_proc)
      selector = @predicate_operator_rule == ALL_RULES ? :all? : :any?

      clear
      @cache.clear

      @libraries.each do |library|
        filtered_library = library.select do |book|
          filters.send(selector) { |filter| filter.call(book) } # Problem here.
        end
        filtered_library.each { |x| @cache[x] = library }
        concat(filtered_library)
      end
      @n_rated = count { |x| !x.rating.nil? && x.rating > 0 }
    end

    def cover(book)
      @cache[book].cover(book)
    end

    def yaml(book = nil)
      if book
        @cache[book].yaml(book)
      else
        File.join(base_dir, @name + EXT)
      end
    end

    def save(book = nil)
      if book
        @cache[book].save(book)
      else
        FileUtils.mkdir_p(base_dir)
        File.open(yaml, "w") { |io| io.puts to_hash.to_yaml }
      end
    end

    def save_cover(book, _cover_uri)
      @cache[book].save_cover(book)
    end

    def final_cover(book)
      @cache[book].final_cover(book)
    end

    def copy_covers(somewhere)
      FileUtils.rm_rf(somewhere)
      FileUtils.mkdir(somewhere)
      each do |book|
        library = @cache[book]
        next unless File.exist?(library.cover(book))

        FileUtils.cp(File.join(library.path, book.ident + Library::EXT[:cover]),
                     File.join(somewhere, library.final_cover(book)))
      end
    end

    def n_unrated
      length - n_rated
    end

    def ==(other)
      other.is_a?(self.class) && other.name == name
    end

    @@deleted_libraries = []

    def self.deleted_libraries
      @@deleted_libraries
    end

    def self.really_delete_deleted_libraries
      @@deleted_libraries.each do |library|
        log.debug { "Deleting smart library file (#{yaml})" }
        FileUtils.rm_rf(library.yaml)
      end
    end

    def delete
      if @@deleted_libraries.include?(self)
        log.info do
          "Already deleted a SmartLibrary with this name (this might mess up undeletes)"
        end
        FileUtils.rm_rf(yaml)
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

    private

    def libraries=(ary)
      @libraries ||= []
      @libraries.each { |x| x.delete_observer(self) }
      @libraries = ary.select { |x| x.is_a?(Library) }
      @libraries.each { |x| x.add_observer(self) }
    end

    def base_dir
      @store.smart_library_dir
    end

    class Rule
      include GetText
      extend GetText
      bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      attr_accessor :operand, :operation, :value

      def initialize(operand, operation, value)
        raise if operand.nil? || operation.nil? # value can be nil

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
          operand: @operand.book_selector,
          operation: @operation.sym,
          value: @value
        }
      end

      Operand = Struct.new(:name, :klass)
      class Operand
        def <=>(other)
          name <=> other.name
        end
      end

      class LeftOperand < Operand
        attr_accessor :book_selector

        def initialize(book_selector, *args)
          super(*args)
          @book_selector = book_selector
        end
      end

      Operator = Struct.new(:sym, :name, :proc)
      class Operator
        def <=>(other)
          name <=> other.name
        end
      end

      module Operands
        include GetText
        extend GetText
        bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

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
        bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

        IS_TRUE = Operator.new(:is_true,
                               _("is set"),
                               proc { |x| x })
        IS_NOT_TRUE = Operator.new(:is_not_true,
                                   _("is not set"),
                                   proc(&:!))
        IS = Operator.new(:is,
                          _("is"),
                          proc { |x, y| x == y })
        IS_NOT = Operator.new(:is_not,
                              _("is not"),
                              proc { |x, y| x != y })
        CONTAINS = Operator.new(:contains,
                                _("contains"),
                                proc { |x, y| x.include?(y) })
        DOES_NOT_CONTAIN = Operator.new(:does_not_contain,
                                        _("does not contain"),
                                        proc { |x, y| !x.include?(y) })
        STARTS_WITH = Operator.new(:starts_with,
                                   _("starts with"),
                                   proc { |x, y| /^#{y}/.match(x) })
        ENDS_WITH = Operator.new(:ends_with,
                                 _("ends with"),
                                 proc { |x, y| /#{y}$/.match(x) })
        IS_GREATER_THAN = Operator.new(:is_greater_than,
                                       _("is greater than"),
                                       proc { |x, y| x > y })
        IS_LESS_THAN = Operator.new(:is_less_than,
                                    _("is less than"),
                                    proc { |x, y| x < y })
        IS_AFTER = Operator.new(:is_after,
                                _("is after"),
                                proc { |x, y| x.to_i > y.to_i && !x.nil? })
        IS_BEFORE = Operator.new(:is_before,
                                 _("is before"),
                                 proc { |x, y| x.to_i < y.to_i && !x.nil? })
        IS_IN_LAST =
          Operator.new(:is_in_last_days,
                       _("is in last"),
                       proc { |x, y|
                         begin
                           if x.nil? || x.empty?
                             false
                           else
                             log.debug { "Given Date: #{x.inspect} #{x.class}" }
                             given_date = Time.parse(x)
                             days = y.to_i * (24 * 60 * 60)

                             Time.now - given_date <= days
                           end
                         rescue StandardError => ex
                           trace = ex.backtrace.join("\n >")
                           log.warn { "Date matching failed #{ex} #{trace}" }
                           false
                         end
                       })
        IS_NOT_IN_LAST =
          Operator.new(:is_not_in_last_days,
                       _("is not in last"),
                       proc { |x, y|
                         begin
                           if x.nil? || x.empty?
                             false
                           else
                             log.debug { "Given Date: #{x.inspect} #{x.class}" }
                             given_date = Time.parse(x)
                             days = y.to_i * (24 * 60 * 60)

                             Time.now - given_date > days
                           end
                         rescue StandardError => ex
                           trace = ex.backtrace.join("\n >")
                           log.warn { "Date matching failed #{ex} #{trace}" }
                           false
                         end
                         # Time.now - x > 3600*24*y
                       })

        ALL = constants.map \
          { |x| module_eval(x.to_s) }.select \
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
        when "String"
          STRING_OPERATORS.map { |x| [x, Operands::STRING] }
        when "Array"
          STRING_ARRAY_OPERATORS.map { |x| [x, Operands::STRING] }
        when "Integer"
          INTEGER_OPERATORS.map { |x| [x, Operands::INTEGER] }
        when "TrueClass"
          BOOLEAN_OPERATORS.map { |x| [x, nil] }
        when "Time"
          TIME_OPERATORS.map do |x|
            if (x == Operators::IS_IN_LAST) ||
                (x == Operators::IS_NOT_IN_LAST)

              [x, Operands::DAYS]
            else
              [x, Operands::TIME]
            end
          end
        else
          raise format(_("invalid operand klass %<klass>s"), klass: operand.klass)
        end
      end

      def filter_proc
        proc do |book|
          left_value = book.send(@operand.book_selector)
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
