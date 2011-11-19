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

module Alexandria
  module UI
    class SmartLibraryPropertiesDialogBase < Gtk::Dialog
      include Logging
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      attr_reader :predicate_operator_rule

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

        @smart_library_rules = []

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
        setup_calendar_widgets
      end

      #########
      protected
      #########

      def smart_library_rules
        fill_smart_library_rules_values
        return @smart_library_rules
      end

      def has_weirdnesses?
        fill_smart_library_rules_values
        smart_library_rules.each do |rule|
          return true if rule.value == ""
        end
        return false
      end

      def user_confirms_possible_weirdnesses_before_saving?
        return true unless has_weirdnesses?
        dialog = AlertDialog.new(
                                 self,
                                 _("Empty or conflictive condition"),
                                 Gtk::Stock::DIALOG_QUESTION,
                                 [[Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                  [_("_Save However"), Gtk::Dialog::RESPONSE_YES]],
                                 _("This smart library contains one or more conditions " +
                                   "which are empty or conflict with each other. This is " +
                                   "likely to result in never matching a book. Are you " +
                                   "sure you want to save this library?"))
        dialog.default_response = Gtk::Dialog::RESPONSE_CANCEL
        dialog.show_all
        confirmed = dialog.run == Gtk::Dialog::RESPONSE_YES
        dialog.destroy
        return confirmed
      end

      def update_rules_header_box(predicate_operator_rule=
                                  SmartLibrary::ALL_RULES)

        @rules_header_box.children.each { |x| @rules_header_box.remove(x) }

        if @rules_box.children.length > 1
          label1 = Gtk::Label.new
          label1.set_alignment(0.0, 0.5)
          label1.text = _("Match")

          cb = Gtk::ComboBox.new
          [_("all"), _("any")].each { |x| cb.append_text(x) }
          cb.signal_connect('changed') do
            @predicate_operator_rule = cb.active == 0 \
            ? SmartLibrary::ALL_RULES : SmartLibrary::ANY_RULE
          end
          cb.active =
            predicate_operator_rule == SmartLibrary::ALL_RULES ? 0 : 1

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
          @predicate_operator_rule = SmartLibrary::ALL_RULES
        end

        @rules_header_box.show_all
      end

      def insert_new_rule(rule=nil)
        rule_box = Gtk::HBox.new
        rule_box.spacing = 8

        left_operand_combo = Gtk::ComboBox.new
        operator_combo = Gtk::ComboBox.new
        operator_model = Gtk::ListStore.new(String)
        # we can't just pass the model to the combo constructor,
        # it doesn't seem to work properly
        operator_combo.model = operator_model

        value_entry = Gtk::Entry.new
        
        date_entry = Gtk::Entry.new
        date_entry.primary_icon_name = Gtk::Stock::EDIT
        date_entry.primary_icon_activatable = true
        date_entry.signal_connect('icon-press') do |entry, primary, icon|
          if primary.nick == 'primary'
            display_calendar_popup(entry)
          end
        end

        # Really hide the time part of the date entry, as the constructor
        # does not seem to do it...
        ###date_entry.children[2..3].each { |x| date_entry.remove(x) }
        ###date_entry.spacing = 8
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
          idx = @rules_box.children.index(rule_box)
          raise if idx.nil?
          @smart_library_rules.delete_at(idx)
          @rules_box.remove(rule_box)
          sensitize_remove_rule_buttons
          update_rules_header_box
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

          idx = @rules_box.children.index(rule_box)
          new_rule = @smart_library_rules[idx]
          if new_rule.nil?
            new_rule = SmartLibrary::Rule.new(operand,
                                              operation.first,
                                              nil)
            @smart_library_rules << new_rule
          end
          new_rule.operand = operand
          new_rule.operation = operation.first
          new_rule.value = nil
        end
        left_operand_combo.signal_connect('changed') do
          operand = operands[left_operand_combo.active]
          operator_combo.freeze_notify do
            operator_combo.model.clear
            operations = SmartLibrary::Rule.operations_for_operand(operand)
            operations.each do |operation|
              operator = operation.first
              iter = operator_combo.model.append
              iter[0] = operator.name
            end
            operator_combo.active = 0
          end
        end

        rule_box.pack_start(left_operand_combo, false, false, 0)
        rule_box.pack_start(operator_combo, false, false, 0)
        rule_box.pack_start(value_entry)
        rule_box.pack_start(date_entry)
        rule_box.pack_start(entry_label, false, false, 0)
        rule_box.pack_end(remove_button, false, false, 0)
        rule_box.pack_end(add_button, false, false, 0)

        rule_box.show_all
        value_entry.visible = date_entry.visible = entry_label.visible =
          false

        @rules_box.pack_start(rule_box, false, true, 0)

        if rule
          operand_idx = operands.index(rule.operand)
          operations =
            SmartLibrary::Rule.operations_for_operand(rule.operand)
          operation_idx = operations.map \
          { |x| x.first }.index(rule.operation)

          if operand_idx != nil and operation_idx != nil
            left_operand_combo.active = operand_idx
            operator_combo.active = operation_idx
            if rule.value != nil
              case rule.value
              when String
                value_entry.text = rule.value
              when Time
                date_entry.text = format_date(rule.value)
              end
            end
          end
        else
          left_operand_combo.active = 0
        end

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

      def fill_smart_library_rules_values
        @rules_box.children.each_with_index do |box, i|
          entry, date = box.children[2..3]
          value = nil
          if entry.visible?
            value = entry.text.strip
          elsif date.visible?
            begin
              value = parse_date(date.text)
            rescue Exception => ex
              trace = ex.backtrace.join("\n > ")
              log.warn { "Possibly invalid date entered #{ex.message}" } 
              log.warn { "Date widget returned #{date.text} / #{trace}" }
              # user entered some non-date... 
              # default to current time, for the moment
              value = Time.now()
            end
          end
          @smart_library_rules[i].value = value
        end
      end

      # COPIED and PASTED from book_properties_dialog_base


      def setup_calendar_widgets
        @popup_displayed = false
        @calendar_popup = Gtk::Window.new()# Gtk::Window::POPUP)
        # @calendar_popup.modal = true
        @calendar_popup.decorated = false
        @calendar_popup.skip_taskbar_hint = true
        @calendar_popup.skip_pager_hint = true
        @calendar_popup.events = [Gdk::Event::FOCUS_CHANGE_MASK]
        
        @calendar_popup.set_transient_for( self )
        @calendar_popup.set_type_hint( Gdk::Window::TYPE_HINT_DIALOG )
        @calendar_popup.name = 'calendar-popup'
        @calendar_popup.resizable = false
        # @calendar_popup.border_width = 4
        # @calendar_popup.app_paintable = true

        @calendar_popup.signal_connect("focus-out-event") do |popup, event|
          hide_calendar_popup
          false
        end

        @calendar = Gtk::Calendar.new
        @calendar_popup.add(@calendar)

        @calendar.signal_connect("day-selected") do
          date_arr = @calendar.date
          year = date_arr[0]
          month = date_arr[1]# + 1 # gtk : months 0-indexed, Time.gm : 1-index
          day = date_arr[2]
          if @calendar_popup_for_entry
            time = Time.gm(year, month, day)
            @calendar_popup_for_entry.text = format_date(time)
          end

        end
        
        @calendar.signal_connect("day-selected-double-click") do
          date_arr = @calendar.date
          year = date_arr[0]
          month = date_arr[1]# + 1 # gtk : months 0-indexed, Time.gm : 1-index
          day = date_arr[2]
          if @calendar_popup_for_entry
            time = Time.gm(year, month, day)
            @calendar_popup_for_entry.text = format_date(time)
          end
          hide_calendar_popup
        end

      end

     def hide_calendar_popup
       @calendar_popup_for_entry = nil

       @calendar_popup.hide_all
       self.modal = true

        Gtk.timeout_add(150) do

          # If we set @popup_displayed=false immediately, then a click
          # event on the primary icon of the Entry simultaneous with
          # the focus-out-event of the Calendar causes the Calendar to
          # pop up again milliseconds after being closed.
          #
          # This is never what the user intends.
          #
          # So we add a small delay before the primary icon's event
          # handler is told to pop up the calendar in response to
          # clicks.

          @popup_displayed = false
          false
        end
      end

      def display_calendar_popup(entry)
        if @popup_displayed
          hide_calendar_popup
        else
          @calendar_popup_for_entry = entry
          unless entry.text.strip.empty?
            time = parse_date(entry.text)
            unless time.nil?
              @calendar.year = time.year
              @calendar.month = time.month - 1
              @calendar.day = time.day
            end
          end
          self.modal = false
          @calendar_popup.move(*get_entry_popup_coords(entry))
          @calendar_popup.show_all
          @popup_displayed = true      
        end
      end

      def get_entry_popup_coords(entry)
        gdk_win = entry.parent_window
        x,y = gdk_win.origin
        alloc = entry.allocation
        x += alloc.x
        y += alloc.y
        y += alloc.height
        #x = [0, x].max
        #y = [0, y].max
        [x, y]
      end

      def parse_date(datestring)
        date_format = '%d/%m/%Y' # or '%m/%d/%Y' for USA and Canada ; or '%Y-%m-%d' for most of Asia
        ## http://en.wikipedia.org/wiki/Calendar_date#Middle_endian_forms.2C_starting_with_the_month
        begin
          d = Date.strptime(datestring, date_format)          
          Time.gm(d.year, d.month, d.day)
        rescue => er
          nil
        end
      end

      def format_date(datetime)
         date_format = '%d/%m/%Y'
        datetime.strftime( date_format = '%d/%m/%Y')
      end

    end
  end
end
