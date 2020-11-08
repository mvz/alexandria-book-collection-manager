# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/calendar_popup"
require "alexandria/ui/smart_library_rule_box"

module Alexandria
  module UI
    class SmartLibraryPropertiesDialogBase
      include Logging
      include CalendarPopup
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      attr_reader :predicate_operator_rule, :dialog

      def initialize(parent)
        @dialog = Gtk::Dialog.new(title: "",
                                  parent: parent,
                                  flags: :modal,
                                  buttons: [[Gtk::Stock::HELP, :help]])

        @dialog.window_position = :center
        @dialog.resizable = true
        @dialog.border_width = 4
        @dialog.child.border_width = 12

        main_box = Gtk::Box.new :vertical
        main_box.border_width = 4
        main_box.spacing = 8

        @dialog.child << main_box

        @smart_library_rules = []

        @rules_header_box = Gtk::Box.new :horizontal
        @rules_header_box.spacing = 2

        @rules_box = Gtk::Box.new :vertical
        @rules_box.spacing = 8
        @rules_box.border_width = 8

        scrollview = Gtk::ScrolledWindow.new
        scrollview.hscrollbar_policy = :never
        scrollview.vscrollbar_policy = :automatic
        scrollview.set_size_request(-1, 125)
        scrollview.add_with_viewport(@rules_box)

        main_box.pack_start(@rules_header_box, expand: false, fill: false)
        main_box << scrollview
        setup_calendar_widgets
      end

      def handle_date_icon_press(widget, primary, _icon)
        display_calendar_popup(widget) if primary.nick == "primary"
      end

      def handle_add_rule_clicked
        insert_new_rule
      end

      def handle_remove_rule_clicked(box_controller)
        remove_rule_box(box_controller.rule_box)
      end

      # TODO: Move logic to SmartLibraryRuleBox
      def apply_smart_rule_for_rule_box(rule_box, operand, operation)
        idx = @rules_box.children.index(rule_box)
        smart_library_rules[idx] ||= SmartLibrary::Rule.new(operand,
                                                            operation.first,
                                                            nil)
        new_rule = smart_library_rules[idx]
        new_rule.operand = operand
        new_rule.operation = operation.first
        new_rule.value = nil
      end

      protected

      attr_reader :smart_library_rules

      def has_weirdnesses?
        fill_smart_library_rules_values
        smart_library_rules.each do |rule|
          return true if rule.value == ""
        end
        false
      end

      def user_confirms_possible_weirdnesses_before_saving?
        return true unless has_weirdnesses?

        dialog = AlertDialog.new(
          @dialog,
          _("Empty or conflictive condition"),
          Gtk::Stock::DIALOG_QUESTION,
          [[Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL],
           [_("_Save However"), Gtk::ResponseType::YES]],
          _("This smart library contains one or more conditions " \
            "which are empty or conflict with each other. This is " \
            "likely to result in never matching a book. Are you " \
            "sure you want to save this library?"))
        dialog.default_response = Gtk::ResponseType::CANCEL
        dialog.show_all
        confirmed = dialog.run == Gtk::ResponseType::YES
        dialog.destroy
        confirmed
      end

      def update_rules_header_box(predicate_operator_rule = SmartLibrary::ALL_RULES)
        @rules_header_box.children.each { |x| @rules_header_box.remove(x) }

        if @rules_box.children.length > 1
          label1 = Gtk::Label.new
          label1.set_alignment(0.0, 0.5)
          label1.text = _("Match")

          cb = Gtk::ComboBoxText.new
          [_("all"), _("any")].each { |x| cb.append_text(x) }
          cb.signal_connect("changed") do
            @predicate_operator_rule =
              cb.active.zero? ? SmartLibrary::ALL_RULES : SmartLibrary::ANY_RULE
          end
          cb.active =
            predicate_operator_rule == SmartLibrary::ALL_RULES ? 0 : 1

          label2 = Gtk::Label.new
          label2.set_alignment(0.0, 0.5)
          label2.text = _("of the following rules:")

          @rules_header_box.pack_start(label1, expand: false, fill: false)
          @rules_header_box.pack_start(cb, expand: false, fill: false)
          @rules_header_box.pack_start(label2, expand: false, fill: false)
        else
          label = Gtk::Label.new
          label.set_alignment(0.0, 0.5)
          label.text = _("Match the following rule:")
          @rules_header_box << label
          @predicate_operator_rule = SmartLibrary::ALL_RULES
        end

        @rules_header_box.show_all
      end

      def make_rule_box(rule = nil)
        box_controller = SmartLibraryRuleBox.new self
        rule_box = box_controller.rule_box
        rule_box.show_all
        @rules_box.pack_start(rule_box, expand: false, fill: true)

        if rule
          operands = SmartLibrary::Rule::Operands::LEFT
          operand_idx = operands.index(rule.operand)
          operations =
            SmartLibrary::Rule.operations_for_operand(rule.operand)
          operation_idx = operations.map(&:first).index(rule.operation)

          if !operand_idx.nil? && !operation_idx.nil?
            box_controller.left_operand_combo.active = operand_idx
            box_controller.operator_combo.active = operation_idx
            unless rule.value.nil?
              case rule.value
              when String
                box_controller.value_entry.text = rule.value
              when Time
                box_controller.date_entry.text = format_date(rule.value)
              end
            end
          end
        else
          box_controller.left_operand_combo.active = 0
        end
      end

      def insert_new_rule(rule = nil)
        make_rule_box(rule)
        @rules_box.check_resize # force a layout
        update_rules_header_box
        sensitize_remove_rule_buttons
      end

      def remove_rule_box(rule_box)
        idx = @rules_box.children.index(rule_box)
        raise if idx.nil?

        smart_library_rules.delete_at(idx)
        @rules_box.remove(rule_box)
        sensitize_remove_rule_buttons
        update_rules_header_box
      end

      def sensitize_remove_rule_buttons
        boxes = @rules_box.children
        state = boxes.length > 1
        boxes.each do |box|
          button = box.children[-1]
          button.sensitive = state if button.is_a?(Gtk::Button)
        end
      end

      def fill_smart_library_rules_values
        @rules_box.children.each_with_index do |box, i|
          entry, date = box.children[2..3]
          value = nil
          if entry.visible?
            value = entry.text.strip
          elsif date.visible?
            begin
              value = parse_date(date.text)
            rescue StandardError => ex
              trace = ex.backtrace.join("\n > ")
              log.warn { "Possibly invalid date entered #{ex.message}" }
              log.warn { "Date widget returned #{date.text} / #{trace}" }
              # user entered some non-date...
              # default to current time, for the moment
              value = Time.now
            end
          end
          smart_library_rules[i].value = value
        end
      end

      def parse_date(datestring)
        # '%m/%d/%Y' for USA and Canada ; or '%Y-%m-%d' for most of Asia
        # http://en.wikipedia.org/wiki/Calendar_date#Middle_endian_forms.2C_starting_with_the_month
        date_format = "%d/%m/%Y"
        begin
          d = Date.strptime(datestring, date_format)
          Time.gm(d.year, d.month, d.day)
        rescue StandardError
          nil
        end
      end

      def format_date(datetime)
        datetime.strftime("%d/%m/%Y")
      end
    end
  end
end
