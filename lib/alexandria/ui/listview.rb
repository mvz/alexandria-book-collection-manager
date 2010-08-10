# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2008 Joseph Method
# Copyright (C) 2010 Cathal Mc Ginley
#
# Alexandria is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License aso
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
    include Logging
    include GetText
    GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")
    class ListViewManager
      include Logging
      include GetText
      include DragAndDropable
      BOOKS_TARGET_TABLE = [["ALEXANDRIA_BOOKS",
        Gtk::Drag::TARGET_SAME_APP,
        0]]

      MAX_RATING_STARS = 5
      module Columns
        COVER_LIST, COVER_ICON, TITLE, TITLE_REDUCED, AUTHORS,
          ISBN, PUBLISHER, PUBLISH_DATE, EDITION, RATING, IDENT,
          NOTES, REDD, OWN, WANT, TAGS, LOANED_TO = (0..17).to_a
      end

      def initialize listview, parent
        @parent = parent
        @prefs = @parent.prefs
        @listview = @parent.listview
        @listview_model = @parent.listview_model
        @filtered_model = @parent.filtered_model
        @model = @parent.model
        @actiongroup = @parent.actiongroup
        setup_books_listview
      end

      def setup_title_column
        title = _("Title")
        log.debug { "Create listview column for %s" % title }
        column = Gtk::TreeViewColumn.new(title)
        column.widget = Gtk::Label.new(title).show
        renderer = Gtk::CellRendererPixbuf.new
        column.pack_start(renderer, false)
        column.set_cell_data_func(renderer) do |column, cell, model, iter|
          iter = @listview_model.convert_iter_to_child_iter(iter)
          iter = @filtered_model.convert_iter_to_child_iter(iter)
          cell.pixbuf = iter[Columns::COVER_LIST]
        end
        renderer = Gtk::CellRendererText.new
        renderer.ellipsize = Pango::ELLIPSIZE_END if Pango.ellipsizable?
        # Editable tree views are behaving strangely
        # make_renderer_editable renderer

        column.pack_start(renderer, true)

        column.set_cell_data_func(renderer) do |column, cell, model, iter|
          iter = @listview_model.convert_iter_to_child_iter(iter)
          iter = @filtered_model.convert_iter_to_child_iter(iter)
          cell.text, cell.editable = iter[Columns::TITLE], false #true
        end

        column.sort_column_id = Columns::TITLE
        column.resizable = true
        @listview.append_column(column)
      end

      def make_renderer_editable renderer
        renderer.signal_connect('editing_started') do |cell, entry,
          path_string|
        log.debug { "editing_started" }
        entry.complete_titles
        end

        renderer.signal_connect('edited') do |cell, path_string, new_string|
          log.debug { "edited" }
          path = Gtk::TreePath.new(path_string)
          path = @listview_model.convert_path_to_child_path(path)
          path = @filtered_model.convert_path_to_child_path(path)
          iter = @listview.model.get_iter(path)
          book = @parent.book_from_iter(@parent.selected_library, iter)
          book.title = new_string
          @listview.freeze
          @iconview.freeze
          @parent.fill_iter_with_book(iter, book)
          @iconview.unfreeze
          @listview.unfreeze
        end
      end

      TEXT_COLUMNS = [
        [ _("Authors"), Columns::AUTHORS ],
        [ _("ISBN"), Columns::ISBN ],
        [ _("Publisher"), Columns::PUBLISHER ],
        [ _("Publish Year"), Columns::PUBLISH_DATE ],
        [ _("Binding"), Columns::EDITION ],
        [ _("Loaned To"), Columns::LOANED_TO ]
      ]
      CHECK_COLUMNS = [
        [ _("Read"), Columns::REDD],
        [ _("Own"), Columns::OWN],
        [ _("Want"), Columns::WANT]
      ]

      def setup_books_listview
        log.debug { "setup_books_listview" }
        @listview.model = @listview_model
        setup_title_column
        TEXT_COLUMNS.each do |title, iterid|
          setup_text_column title, iterid
        end
        CHECK_COLUMNS.each do |title, iterid|
          setup_check_column title, iterid
        end
        setup_rating_column
        @listview.selection.mode = Gtk::SELECTION_MULTIPLE
        @listview.selection.signal_connect('changed') do
          log.debug { "changed" }
          @parent.on_books_selection_changed
        end
        setup_tags_column
        setup_listview_hack
        setup_view_source_dnd(@listview)
      end

      def setup_tags_column
        # adding tags column...
        title = _("Tags")
        log.debug { "Create listview column for tags..." }
        renderer = Gtk::CellRendererText.new
        renderer.ellipsize = Pango::ELLIPSIZE_END if Pango.ellipsizable?
        column = Gtk::TreeViewColumn.new(title, renderer,
                                         :text => Columns::TAGS)
        column.widget = Gtk::Label.new(title).show
        column.sort_column_id = Columns::TAGS
        column.resizable = true
        @listview.append_column(column)
      end

      def setup_listview_hack
        @listview.signal_connect('row-activated') do
          # Dirty hack to avoid the beginning of a drag within this
          # handler.
          log.debug { "row-activated" }
          Gtk.timeout_add(100) do
            @actiongroup["Properties"].activate
            false
          end
        end
      end

      def setup_rating_column
        title = _("Rating")
        log.debug { "Create listview column for %s..." % title }
        column = Gtk::TreeViewColumn.new(title)
        column.widget = Gtk::Label.new(title).show
        column.sizing = Gtk::TreeViewColumn::FIXED
        column.fixed_width = column.min_width = column.max_width =
          (Icons::STAR_SET.width + 1) * MAX_RATING_STARS
        MAX_RATING_STARS.times do |i|
          renderer = Gtk::CellRendererPixbuf.new
          column.pack_start(renderer, false)
          column.set_cell_data_func(renderer) do |column, cell,model, iter|
            iter = @listview_model.convert_iter_to_child_iter(iter)
            iter = @filtered_model.convert_iter_to_child_iter(iter)
            rating = (iter[Columns::RATING] - MAX_RATING_STARS).abs
            cell.pixbuf = rating >= i.succ ?
              Icons::STAR_SET : Icons::STAR_UNSET
          end
        end
        column.sort_column_id = Columns::RATING
        column.resizable = false
        @listview.append_column(column)
      end

      def setup_check_column title, iterid
        renderer= CellRendererToggle.new
        renderer.activatable = true
        renderer.signal_connect('toggled') do |rndrr, path|
          begin
            tree_path = Gtk::TreePath.new(path)
            child_path = @listview_model.convert_path_to_child_path(tree_path)
            if child_path
              unfiltered_path = @filtered_model.convert_path_to_child_path(child_path)
              # FIX this sometimes returns a nil path for iconview...
              if unfiltered_path
                iter = @model.get_iter(unfiltered_path)
                if iter
                  book = @parent.book_from_iter(@parent.selected_library, iter)
                  toggle_state = case iterid
                                 when Columns::REDD then book.redd
                                 when Columns::OWN then book.own
                                 when Columns::WANT then book.want
                                 end
                  # invert toggle_state
                  unless (iterid==Columns::WANT && book.own)
                    toggle_state = !toggle_state
                    case iterid
                    when Columns::REDD then book.redd = toggle_state
                    when Columns::OWN then book.own = toggle_state
                    when Columns::WANT then book.want = toggle_state
                    end
                    iter[iterid] = toggle_state    
                    lib = @parent.selected_library
                    lib.save(book)
                  end
                end
              end
              
            end
          rescue ::Exception => e
            log.error { "toggle failed for path #{path} #{e}\n" + e.backtrace.join("\n") }
          end

        end
        column = Gtk::TreeViewColumn.new(title, renderer, :text => iterid)
        column.widget = Gtk::Label.new(title).show
        column.sort_column_id = iterid
        column.resizable = true
        log.debug { "Create listview column for %s..." % title }
        setup_column = Proc.new do |iter, cell, column|
          state = iter[column]
          cell.set_active(state)
          cell.activatable = true
        end
        log.debug { "Setting cell_data_func for #{renderer}" }
        column.set_cell_data_func(renderer) do |column, cell, model, iter|
          iter = @listview_model.convert_iter_to_child_iter(iter)
          iter = @filtered_model.convert_iter_to_child_iter(iter)
          case iterid
          when 12
            setup_column.call(iter, cell, Columns::REDD)
          when 13
            setup_column.call(iter, cell, Columns::OWN)
          when 14
            setup_column.call(iter, cell, Columns::WANT)
            own_state = iter[Columns::OWN]
            cell.inconsistent = own_state
          end
        end
        log.debug { "append_column #{column}" }
        @listview.append_column(column)

      end

      def setup_text_column title, iterid
        log.debug { "Create listview column for %s..." % title }
        renderer = Gtk::CellRendererText.new
        renderer.ellipsize = Pango::ELLIPSIZE_END if Pango.ellipsizable?
        column = Gtk::TreeViewColumn.new(title, renderer,
                                         :text => iterid)
        column.widget = Gtk::Label.new(title).show
        column.sort_column_id = iterid
        column.resizable = true
        @listview.append_column(column)
      end

      def setup_listview_columns_visibility
        log.debug { "setup_listview_columns_visibility" }
        # Show or hide list view columns according to the preferences.
        cols_visibility = [
          @prefs.col_authors_visible,
          @prefs.col_isbn_visible,
          @prefs.col_publisher_visible,
          @prefs.col_publish_date_visible,
          @prefs.col_edition_visible,
          @prefs.col_loaned_to_visible,
          @prefs.col_redd_visible,
          @prefs.col_own_visible,
          @prefs.col_want_visible,
          @prefs.col_rating_visible,
          @prefs.col_tags_visible
        ]
        cols = @listview.columns[1..-1] # skip "Title"
        cols.each_index do |i|
          cols[i].visible = cols_visibility[i]
        end
        log.debug { "Columns visibility: " + cols.collect {|col| "#{col.title} #{col.visible?.to_s}"}.join(", ") }
      end

      # Sets the width of each column based on any respective
      # preference value stored.
      def setup_listview_columns_width
        log.debug { "setup_listview_columns_width #{@prefs.cols_width}" }
        if @prefs.cols_width
          cols_width = YAML.load(@prefs.cols_width)
          log.debug { "cols_width: #{cols_width.inspect }" }
          @listview.columns.each do |c|
            if cols_width.has_key?(c.title)
              log.debug { "#{c.title} : #{cols_width[c.title]}" }
              c.sizing = Gtk::TreeViewColumn::FIXED
              c.fixed_width = cols_width[c.title]
            end
          end
        end
        log.debug { "Columns width: " + @listview.columns.collect {|col| "#{col.title} #{col.width.to_s}"}.join(", ") }
      end
    end
  end
end
