# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

module Alexandria
  module UI
    class SmartLibraryRuleBox
      attr_accessor :rule_box, :left_operand_combo, :operator_combo, :value_entry, :date_entry, :entry_label, :add_button, :remove_button

      def initialize(parent)
        @parent = parent

        self.rule_box = Gtk::Box.new :horizontal
        rule_box.spacing = 8

        self.left_operand_combo = Gtk::ComboBoxText.new
        self.operator_combo = Gtk::ComboBoxText.new

        self.value_entry = Gtk::Entry.new

        self.date_entry = Gtk::Entry.new.tap do |entry|
          entry.primary_icon_name = Gtk::Stock::EDIT

          entry.primary_icon_activatable = true
          entry.signal_connect("icon-press") do |widget, primary, _icon|
            @parent.handle_date_icon_press(widget, primary, icon)
          end
        end

        self.entry_label = Gtk::Label.new("")

        self.add_button = Gtk::Button.new(label: "").tap do |widget|
          widget.remove(widget.children.first)
          widget << Gtk::Image.new(stock: Gtk::Stock::ADD,
                                   size: Gtk::IconSize::BUTTON)

          widget.signal_connect("clicked") { @parent.handle_add_rule_clicked }
        end

        self.remove_button = Gtk::Button.new(label: "")
        remove_button.remove(remove_button.children.first)
        remove_button << Gtk::Image.new(stock: Gtk::Stock::REMOVE,
                                        size: Gtk::IconSize::BUTTON)

        remove_button.signal_connect("clicked") do |_button|
          @parent.handle_remove_rule_clicked(self)
        end

        operands.each do |operand|
          left_operand_combo.append_text(operand.name)
        end

        operator_combo.signal_connect("changed") do
          handle_operator_changed
        end

        left_operand_combo.signal_connect("changed") do
          handle_left_operand_changed
        end

        rule_box.pack_start(left_operand_combo, expand: false, fill: false)
        rule_box.pack_start(operator_combo, expand: false, fill: false)
        rule_box.pack_start(value_entry)
        rule_box.pack_start(date_entry)
        rule_box.pack_start(entry_label, expand: false, fill: false)
        rule_box.pack_end(remove_button, expand: false, fill: false)
        rule_box.pack_end(add_button, expand: false, fill: false)

        value_entry.visible = date_entry.visible = entry_label.visible = false
      end

      def operands
        SmartLibrary::Rule::Operands::LEFT
      end

      def handle_operator_changed
        operand = operands[left_operand_combo.active]
        operations = SmartLibrary::Rule.operations_for_operand(operand)
        operation = operations[operator_combo.active]

        value_entry.visible = date_entry.visible = entry_label.visible = false
        right_operand = operation.last
        unless right_operand.nil?
          entry = case right_operand.klass.name
                  when "Time"
                    date_entry
                  else
                    value_entry
                  end
          entry.visible = true
          unless right_operand.name.nil?
            entry_label.text = right_operand.name
            entry_label.visible = true
          end
        end

        @parent.apply_smart_rule_for_rule_box(rule_box, operand, operation)
      end

      def handle_left_operand_changed
        operand = operands[left_operand_combo.active]
        operator_combo.freeze_notify do
          operator_combo.remove_all
          operations = SmartLibrary::Rule.operations_for_operand(operand)
          operations.each do |operation|
            operator = operation.first
            operator_combo.append_text(operator.name)
          end
          operator_combo.active = 0
        end
      end
    end
  end
end
