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
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

module Alexandria
module UI
    class Rule
    end

    class SmartLibraryPropertiesDialogBase < Gtk::Dialog
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent)
            super("", parent, Gtk::Dialog::MODAL, 
                  [Gtk::Stock::HELP, Gtk::Dialog::RESPONSE_HELP])
           
            self.window_position = Gtk::Window::POS_CENTER 
            self.has_separator = false
            self.resizable = true 
            self.border_width = 4
            self.vbox.border_width = 12

            main_box = Gtk::VBox.new
            main_box.border_width = 4
            main_box.spacing = 8

            self.vbox << main_box

            @rules_header_box = Gtk::HBox.new
            @rules_header_box.spacing = 2
 
            @rules_box = Gtk::VBox.new
            @rules_box.spacing = 8 
            @rules_box.border_width = 8

            scrollview = Gtk::ScrolledWindow.new
            scrollview.hscrollbar_policy = Gtk::POLICY_NEVER
            scrollview.vscrollbar_policy = Gtk::POLICY_AUTOMATIC
            scrollview.set_size_request(-1, 125)
            scrollview.add_with_viewport(@rules_box)

            main_box.pack_start(@rules_header_box, false, false, 0)
            main_box << scrollview
        end

        #########
        protected
        #########

        def update_rules_header_box
            @rules_header_box.children.each { |x| @rules_header_box.remove(x) }

            if @rules_box.children.length > 1 
                label1 = Gtk::Label.new
                label1.set_alignment(0.0, 0.5)
                label1.text = _("Match")
               
                cb = Gtk::ComboBox.new
                [_("all"), _("any")].each { |x| cb.append_text(x) }
                cb.active = 0 

                label2 = Gtk::Label.new
                label2.set_alignment(0.0, 0.5)
                label2.text = _("of the following rules:")
                
                @rules_header_box.pack_start(label1, false, false, 0)
                @rules_header_box.pack_start(cb, false, false, 0)
                @rules_header_box.pack_start(label2, false, false, 0)
            else
                label = Gtk::Label.new
                label.set_alignment(0.0, 0.5)
                label.text = _("Match the following rule:")
                @rules_header_box << label                 
            end

            @rules_header_box.show_all
        end

        def insert_new_rule
            rule_box = Gtk::HBox.new
            rule_box.spacing = 8

            left_operand_combo = Gtk::ComboBox.new
            operator_combo = Gtk::ComboBox.new
            value_entry = Gtk::Entry.new
            date_entry = Gnome::DateEdit.new(0, false, false)
            # Really hide the time part of the date entry, as the constructor
            # does not seem to do it...
            date_entry.children[2..3].each { |x| date_entry.remove(x) }
            date_entry.spacing = 8 
            entry_label = Gtk::Label.new("")

            add_button = Gtk::Button.new("")
            add_button.remove(add_button.children.first)
            add_button << Gtk::Image.new(Gtk::Stock::ADD, 
                                         Gtk::IconSize::BUTTON)
        
            add_button.signal_connect('clicked') { insert_new_rule }

            remove_button = Gtk::Button.new("")
            remove_button.remove(remove_button.children.first)
            remove_button << Gtk::Image.new(Gtk::Stock::REMOVE, 
                                            Gtk::IconSize::BUTTON)

            remove_button.signal_connect('clicked') do |button|
                @rules_box.children.each do |box|
                    if box.children.include?(button)
                        @rules_box.remove(box)
                        sensitize_remove_rule_buttons
                        update_rules_header_box
                        break
                    end
                end
            end

            operands = SmartLibrary::Rule::Operands::LEFT
            operands.each do |operand|
                left_operand_combo.append_text(operand.name)
            end
            operator_combo.signal_connect('changed') do
                operand = operands[left_operand_combo.active]
                operations = SmartLibrary::Rule.operations_for_operand(operand)
                operation = operations[operator_combo.active]
                
                value_entry.visible = date_entry.visible = 
                    entry_label.visible = false
                right_operand = operation.last
                unless right_operand.nil?
                    entry = case right_operand.klass.name
                        when 'Time'
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
            end
            left_operand_combo.signal_connect('changed') do
                operand = operands[left_operand_combo.active]
                operator_combo.model.clear
                operations = SmartLibrary::Rule.operations_for_operand(operand)
                operations.each do |operation|
                    operator = operation.first
                    operator_combo.append_text(operator.name)
                end
                operator_combo.active = 0
            end

            rule_box.pack_start(left_operand_combo, false, false, 0)
            rule_box.pack_start(operator_combo, false, false, 0)
            rule_box.pack_start(value_entry)
            rule_box.pack_start(date_entry)
            rule_box.pack_start(entry_label, false, false, 0)
            rule_box.pack_start(add_button, false, false, 0)
            rule_box.pack_start(remove_button, false, false, 0)

            rule_box.show_all
            value_entry.visible = date_entry.visible = entry_label.visible = 
                false

            left_operand_combo.active = 0
            
            @rules_box.pack_start(rule_box, false, true, 0)
            @rules_box.check_resize     # force a layout
            update_rules_header_box
            sensitize_remove_rule_buttons
        end

        def sensitize_remove_rule_buttons
            boxes = @rules_box.children
            state = boxes.length > 1
            boxes.each do |box|
                button = box.children[-1]
                if button.is_a?(Gtk::Button)
                    button.sensitive = state
                end
            end
        end
    end
end
end
