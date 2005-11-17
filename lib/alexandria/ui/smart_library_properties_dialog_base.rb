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
module UI
    class Rule
    end

    class SmartLibraryPropertiesDialogBase < Gtk::Dialog
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize(parent)
            super("", parent, Gtk::Dialog::MODAL, 
                  [Gtk::Stock::HELP, Gtk::Dialog::RESPONSE_HELP])
            
            self.has_separator = false
            self.resizable = false
            self.vbox.border_width = 12

            main_box = Gtk::VBox.new
            main_box.border_width = 4
            main_box.spacing = 8

            self.vbox << main_box

            @rules_header_label = Gtk::Label.new
            @rules_header_label.set_alignment(0.0, 0.0)
            
            @rules_box = Gtk::VBox.new
            @rules_box.spacing = 8 

            main_box << @rules_header_label
            main_box << @rules_box

            self.show_all
        end

        #########
        protected
        #########

        def update_rules_header_label
            @rules_header_label.text = if @rules_box.children.length > 1
                _("Match [all|any] of the following rules:")
            else
                _("Match the following rule:")
            end
        end

        def insert_new_rule
            rule_box = Gtk::HBox.new
            rule_box.spacing = 8

            left_operand_combo = Gtk::ComboBox.new
            operator_combo = Gtk::ComboBox.new
            value_entry = Gtk::Entry.new

            operands = SmartLibrary::Rule::LEFT_OPERANDS
            operands.each do |operand|
                left_operand_combo.append_text(operand.name)
            end
            left_operand_combo.signal_connect('changed') do
                operand = operands[left_operand_combo.active]
                operator_combo.model.clear
                operators = SmartLibrary::Rule.operators_for_operand(operand)
                operators.each do |operator|
                    operator_combo.append_text(operator.name)
                end
                operator_combo.active = 0
            end
            left_operand_combo.active = 0

            rule_box << left_operand_combo
            rule_box << operator_combo
            rule_box << value_entry

            rule_box.show_all

            @rules_box << rule_box
            update_rules_header_label
        end
    end
end
end
