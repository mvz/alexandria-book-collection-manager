# frozen_string_literal: true

# Copyright (C) 2008 Joseph Method
# Copyright (C) 2008,2009 Cathal Mc Ginley
# Copyright (C) 2011, 2014-2016 Matijs van Zuijlen
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
    class SidePaneManager
      include Logging
      include GetText
      attr_accessor :library_listview
      def initialize(library_listview, parent)
        @library_listview = library_listview
        @parent = parent
        @libraries = Libraries.instance
        @main_app = @parent.main_app
        setup_sidepane
      end

      def library_already_exists(new_text)
        x = (@libraries.all_libraries + Library.deleted_libraries).find do |library|
          library.name == new_text.strip
        end
        x && (x.name != @parent.selected_library.name)
      end

      # if new_text is invalid utf-8, returns true
      # if new_text contains disallowed char (/ or initial .), returns a MatchData object
      # otherwise returns nil
      def contains_illegal_character(new_text)
        new_text.unpack('U*') # attempt to unpack as UTF-8 characters
        match = /(^\.|\/)/.match(new_text)
        # forbid / character (since Library names become dir names)
        # also no initial . since that hides the Library (hidden file)
        #      forbidding an initial dot also disallows "." and ".."
        #      which are of course pre-existing directories.
        match
      rescue StandardError => ex
        log.warn { "New library name not valid UTF-8: #{ex.message}" }
        true
        # /([^\w\s'"()&?!:;.\-])/.match(new_text) # anglocentric!
      end

      def on_edited_library(cell, path_string, new_text)
        log.debug { "edited library name #{new_text}" }
        ## new_text = new_text.reverse # for testing;
        # a great way to generate broken UTF-8
        if cell.text != new_text
          if (match = contains_illegal_character(new_text))
            if match.instance_of? MatchData
              chars = match[1].gsub(/&/, '&amp;')
              ErrorDialog.new(@main_app, _("Invalid library name '%s'") % new_text,
                              _('The name provided contains the ' \
                                'disallowed character <b>%s</b> ') % chars).display
            else
              ErrorDialog.new(@main_app, _('Invalid library name'),
                              _('The name provided contains ' \
                                'invalid characters.')).display
            end

          elsif new_text.strip.empty?
            log.debug { 'Empty text' }
            ErrorDialog.new(@main_app, _('The library name ' \
                                         'can not be empty')).display
          elsif library_already_exists new_text
            log.debug { 'Already exists' }
            ErrorDialog.new(@main_app,
                            _('The library can not be renamed'),
                            _('There is already a library named ' \
                              "'%s'.  Please choose a different " \
                              'name.') % new_text.strip).display
          else
            log.debug { "Attempting to apply #{path_string}, #{new_text}" }
            path = Gtk::TreePath.new(path_string)
            iter = @library_listview.model.get_iter(path)
            library_name = new_text.strip
            log.info { "library name is #{library_name}" }
            iter[1] = @parent.selected_library.name = library_name
            @parent.setup_move_actions
            @parent.refresh_libraries
          end
        end
      end

      def setup_sidepane
        @library_listview.model = Gtk::ListStore.new(GdkPixbuf::Pixbuf,
                                                     String,
                                                     TrueClass,
                                                     TrueClass)
        @library_separator_iter = nil
        @libraries.all_regular_libraries.each { |x| @parent.append_library(x) }
        @libraries.all_smart_libraries.each { |x| @parent.append_library(x) }

        renderer = Gtk::CellRendererPixbuf.new
        column = Gtk::TreeViewColumn.new(_('Library'))
        column.pack_start(renderer, false)
        column.set_cell_data_func(renderer) do |_col, cell, _model, iter|
          # log.debug { "sidepane: cell_data_func #{col}, #{cell}, #{iter}" }
          cell.pixbuf = iter[0]
        end
        renderer = Gtk::CellRendererText.new
        renderer.ellipsize = :end
        column.pack_start(renderer, true)
        column.set_cell_data_func(renderer) do |_col, cell, _model, iter|
          # log.debug { "sidepane: editable #{cell}, #{iter} #{iter[1]}: #{iter[2]}" }
          cell.text = iter[1]
          cell.editable = iter[2]
          # log.debug { "exit sidepane: editable #{cell}, #{iter}" }
        end
        renderer.signal_connect('edited', &method(:on_edited_library))
        @library_listview.append_column(column)

        @library_listview.set_row_separator_func do |model, iter|
          # TODO: Replace with iter[3] if possible
          model.get_value(iter, 3)
        end

        @library_listview.selection.signal_connect('changed') do
          log.debug { 'changed' }
          @parent.refresh_libraries
          @parent.refresh_books
        end

        @library_listview.enable_model_drag_dest(BOOKS_TARGET_TABLE, :move)

        @library_listview.signal_connect('drag-motion') do |_widget, drag_context, x, y, time, _data|
          log.debug { 'drag-motion' }

          path, column, =
            @library_listview.get_path_at_pos(x, y)

          if path
            # Refuse drags from/to smart libraries.
            if @parent.selected_library.is_a?(SmartLibrary)
              path = nil
            else
              iter = @library_listview.model.get_iter(path)
              if iter[3] # separator?
                path = nil
              else
                library = @libraries.all_libraries.find do |lib|
                  lib.name == iter[1]
                end
                path = nil if library.is_a?(SmartLibrary)
              end
            end
          end

          @library_listview.set_drag_dest_row(path, :into_or_after)

          Gdk.drag_status(drag_context,
                          path ? drag_context.suggested_action : 0,
                          time)
        end

        @library_listview.signal_connect('drag-drop') do |widget, drag_context, _x, _y, time, _data|
          log.debug { 'drag-drop' }

          widget.drag_get_data(drag_context,
                               drag_context.targets.first,
                               time)
          true
        end

        @library_listview.signal_connect('drag-data-received') do |_, drag_context, x, y, data, _, _|
          log.debug { 'drag-data-received' }

          success = false
          # FIXME: Ruby-GNOME2 should make comparison work without needing to
          # call #name.
          if data.data_type.name == Gdk::Selection::TYPE_STRING.name
            success, path =
              @library_listview.get_dest_row_at_pos(x, y)

            if success
              iter = @library_listview.model.get_iter(path)
              library = @libraries.all_libraries.find do |lib|
                lib.name == iter[1]
              end
              @parent.move_selected_books_to_library(library)
              success = true
            end
          end
          begin
            drag_context.finish(success: success, delete: false)
          rescue StandardError => ex
            log.error { "drag_context.finish failed: #{ex}" }
            raise
          end
        end
      end
    end
  end
end
