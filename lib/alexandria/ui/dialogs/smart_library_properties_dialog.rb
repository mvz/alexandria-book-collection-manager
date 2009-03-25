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
    class SmartLibraryPropertiesDialog < SmartLibraryPropertiesDialogBase
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      def initialize(parent, smart_library, &block)
        super(parent)

        add_buttons([Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                    [Gtk::Stock::SAVE, Gtk::Dialog::RESPONSE_OK])

        self.title = _("Properties for '%s'") % smart_library.name
        self.default_response = Gtk::Dialog::RESPONSE_CANCEL

        show_all
        smart_library.rules.each { |x| insert_new_rule(x) }
        update_rules_header_box(smart_library.predicate_operator_rule)

        while (response = run) != Gtk::Dialog::RESPONSE_CANCEL
          if response == Gtk::Dialog::RESPONSE_HELP
            Alexandria::UI::display_help(self, 'edit-smart-library')
          elsif response == Gtk::Dialog::RESPONSE_OK
            if user_confirms_possible_weirdnesses_before_saving?
              smart_library.rules = self.smart_library_rules
              smart_library.predicate_operator_rule =
                self.predicate_operator_rule
              smart_library.save
              block.call(smart_library)
              break
            end
          end
        end

        destroy
      end
    end
  end
end
