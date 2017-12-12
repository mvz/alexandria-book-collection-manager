# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2015, 2016 Matijs van Zuijlen
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
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: 'UTF-8')

      def initialize(parent)
        super(parent)

        add_buttons([Gtk::Stock::CANCEL, :cancel],
                    [Gtk::Stock::NEW, :ok])

        self.title = _('New Smart Library')
        # FIXME: Should accept just :cancel
        self.default_response = Gtk::ResponseType::CANCEL

        show_all
        insert_new_rule

        while ((response = run) != :cancel) &&
            (response != :delete_event)

          if response == :help
            Alexandria::UI.display_help(self, 'new-smart-library')
          elsif response == :ok
            if user_confirms_possible_weirdnesses_before_saving?
              rules = smart_library_rules
              basename = smart_library_base_name(rules) || _('Smart Library')
              name = Library.generate_new_name(
                Libraries.instance.all_libraries,
                basename)
              library = SmartLibrary.new(name,
                                         rules,
                                         predicate_operator_rule)
              yield(library)
              break
            end
          end
        end

        destroy
      end

      private

      def smart_library_base_name(rules)
        if rules.length == 1
          value = rules.first.value
          return value if value.is_a?(String) && !value.strip.empty?
        end
      end
    end
  end
end
