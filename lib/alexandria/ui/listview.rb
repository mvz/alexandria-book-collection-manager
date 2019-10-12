# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require 'alexandria/ui/columns'

module Alexandria
  module UI
    include Logging
    include GetText
    GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: 'UTF-8')
    class ListViewManager
      include Logging
      include GetText
      include DragAndDropable
      BOOKS_TARGET_TABLE = [['ALEXANDRIA_BOOKS', :same_app, 0]].freeze

      def initialize(_listview, parent)
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
        title = _('Title')
        log.debug { format('Create listview column for %s', title) }
        column = Gtk::TreeViewColumn.new(title)

        renderer = Gtk::CellRendererPixbuf.new
        column.pack_start(renderer, false)
        column.add_attribute(renderer, 'pixbuf', Columns::COVER_LIST)

        renderer = Gtk::CellRendererText.new
        renderer.ellipsize = :end
        column.pack_start(renderer, true)
        column.add_attribute(renderer, 'text', Columns::TITLE)

        column.sort_column_id = Columns::TITLE
        column.resizable = true
        @listview.append_column(column)
      end

      TEXT_COLUMNS = [
        [_('Authors'), Columns::AUTHORS],
        [_('ISBN'), Columns::ISBN],
        [_('Publisher'), Columns::PUBLISHER],
        [_('Publish Year'), Columns::PUBLISH_DATE],
        [_('Binding'), Columns::EDITION],
        [_('Loaned To'), Columns::LOANED_TO]
      ].freeze
      CHECK_COLUMNS = [
        [_('Read'), Columns::REDD],
        [_('Own'), Columns::OWN],
        [_('Want'), Columns::WANT]
      ].freeze

      def setup_books_listview
        log.debug { 'setup_books_listview' }
        @listview.model = @listview_model
        setup_title_column
        TEXT_COLUMNS.each do |title, iterid|
          setup_text_column title, iterid
        end
        CHECK_COLUMNS.each do |title, iterid|
          setup_check_column title, iterid
        end
        setup_rating_column
        @listview.selection.mode = :multiple
        @listview.selection.signal_connect('changed') do
          log.debug { 'changed' }
          @parent.on_books_selection_changed
        end
        setup_tags_column
        setup_row_activation
        setup_view_source_dnd(@listview)
      end

      def setup_tags_column
        # adding tags column...
        title = _('Tags')
        log.debug { 'Create listview column for tags...' }
        renderer = Gtk::CellRendererText.new
        renderer.ellipsize = :end
        column = Gtk::TreeViewColumn.new(title, renderer,
                                         text: Columns::TAGS)
        column.sort_column_id = Columns::TAGS
        column.resizable = true
        @listview.append_column(column)
      end

      def setup_row_activation
        @listview.signal_connect('row-activated') do
          log.debug { 'row-activated' }
          @actiongroup['Properties'].activate
          false
        end
      end

      def setup_rating_column
        title = _('Rating')
        log.debug { format('Create listview column for %s...', title) }
        column = Gtk::TreeViewColumn.new(title)
        column.sizing = :fixed
        width = (Icons::STAR_SET.width + 1) * Book::MAX_RATING_STARS
        column.fixed_width = column.min_width = column.max_width = width
        Book::MAX_RATING_STARS.times do |i|
          renderer = Gtk::CellRendererPixbuf.new
          renderer.xalign = 0.0
          column.pack_start(renderer, false)
          column.set_cell_data_func(renderer) do |_tree_column, cell, _tree_model, iter|
            rating = (iter[Columns::RATING] - Book::MAX_RATING_STARS).abs
            cell.pixbuf = rating >= i.succ ? Icons::STAR_SET : Icons::STAR_UNSET
          end
        end
        column.sort_column_id = Columns::RATING
        column.resizable = false
        @listview.append_column(column)
      end

      def setup_check_column(title, iterid)
        renderer = CellRendererToggle.new
        renderer.activatable = true
        renderer.signal_connect('toggled') do |_rndrr, path|
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
                  unless iterid == Columns::WANT && book.own
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
          rescue StandardError => ex
            log.error { "toggle failed for path #{path} #{ex}\n" + e.backtrace.join("\n") }
          end
        end
        column = Gtk::TreeViewColumn.new(title, renderer, text: iterid)
        column.sort_column_id = iterid
        column.resizable = true
        log.debug { format('Create listview column for %s...', title) }

        column.add_attribute(renderer, 'active', iterid)
        column.add_attribute(renderer, 'inconsistent', Columns::OWN) if iterid == Columns::WANT

        log.debug { "append_column #{column}" }
        @listview.append_column(column)
      end

      def setup_text_column(title, iterid)
        log.debug { format('Create listview column for %s...', title) }
        renderer = Gtk::CellRendererText.new
        renderer.ellipsize = :end
        column = Gtk::TreeViewColumn.new(title, renderer,
                                         text: iterid)
        column.sort_column_id = iterid
        column.resizable = true
        @listview.append_column(column)
      end

      def setup_listview_columns_visibility
        log.debug { 'setup_listview_columns_visibility' }
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
          cols[i].visible = !!cols_visibility[i]
        end
        log.debug { 'Columns visibility: ' + cols.map { |col| "#{col.title} #{col.visible?}" }.join(', ') }
      end

      # Sets the width of each column based on any respective
      # preference value stored.
      def setup_listview_columns_width
        log.debug { "setup_listview_columns_width #{@prefs.cols_width}" }
        if @prefs.cols_width
          cols_width = YAML.safe_load(@prefs.cols_width)
          log.debug { "cols_width: #{cols_width.inspect}" }
          @listview.columns.each do |c|
            if cols_width.key?(c.title)
              log.debug { "#{c.title} : #{cols_width[c.title]}" }
              width = cols_width[c.title]
              next if width.zero?

              c.sizing = :fixed
              c.fixed_width = width
            end
          end
        end
        log.debug {
          'Columns width: ' +
            @listview.columns.map { |col| "#{col.title} #{col.width}" }.join(', ')
        }
      end
    end
  end
end
