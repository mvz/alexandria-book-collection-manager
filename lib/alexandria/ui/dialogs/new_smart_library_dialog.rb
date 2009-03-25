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
    class NewSmartLibraryDialog < SmartLibraryPropertiesDialogBase
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      def initialize(parent, &block)
        super(parent)

        add_buttons([Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                    [Gtk::Stock::NEW, Gtk::Dialog::RESPONSE_OK])

        self.title = _('New Smart Library')
        self.default_response = Gtk::Dialog::RESPONSE_CANCEL

        show_all
        insert_new_rule

        while (response = run) != Gtk::Dialog::RESPONSE_CANCEL and
            response != Gtk::Dialog::RESPONSE_DELETE_EVENT

          if response == Gtk::Dialog::RESPONSE_HELP
            Alexandria::UI::display_help(self, 'new-smart-library')
          elsif response == Gtk::Dialog::RESPONSE_OK
            if user_confirms_possible_weirdnesses_before_saving?
              rules = smart_library_rules
              basename = if rules.length == 1 and
                             rules.first.value.is_a?(String) and
                             not rules.first.value.strip.empty?
                           rules.first.value
                         else
                           _('Smart Library')
                         end
              name = Library.generate_new_name(
                                               Libraries.instance.all_libraries,
                                               basename)
              library = SmartLibrary.new(name,
                                         rules,
                                         predicate_operator_rule)
              block.call(library)
              break
            end
          end
        end

        destroy
      end
    end
  end
end
