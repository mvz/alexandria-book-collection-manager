# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/callbacks"
require "alexandria/ui/columns"
require "alexandria/ui/conflict_while_copying_dialog"
require "alexandria/library_sort_order"

module Alexandria
  module UI
    class UIManager < BuilderBase
      attr_accessor :main_app, :actiongroup, :appbar, :prefs, :listview, :iconview,
                    :listview_model, :iconview_model, :filtered_model
      attr_reader :model

      include Logging
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      def initialize(parent)
        super("main_app__builder.glade", widget_names)
        @parent = parent

        @library_separator_iter = nil
        @libraries = nil
        @move_mid = nil
        @clicking_on_sidepane = true

        get_preferences
        load_libraries
        setup_window_icons
        setup_callbacks
        create_uimanager
        add_menus_and_popups_from_xml
        setup_menus
        setup_toolbar
        setup_move_actions
        setup_active_model
        setup_dependents
        setup_accel_group
        setup_popups
        setup_window_events
        setup_books_iconview_sorting
        on_books_selection_changed
        restore_preferences
        log.debug { "UI Manager initialized: #{@iconview.model.inspect}" }
        @clicking_on_sidepane = true

        @library_listview.signal_connect("cursor-changed") do
          @clicking_on_sidepane = true
        end
      end

      def show
        @main_app.show
      end

      def widget_names
        [:main_app, :paned, :vbox1, :library_listview,
         :notebook, :iconview, :listview, :status_label, :appbar,
         :progressbar]
      end

      def create_uimanager
        log.debug { "Adding actiongroup to uimanager" }
        @uimanager = Gtk::UIManager.new
        @uimanager.insert_action_group(@actiongroup, 0)
      end

      def setup_dependents
        @listview_model = Gtk::TreeModelSort.new(@filtered_model)
        @iconview_model = Gtk::TreeModelSort.new(@filtered_model)
        @listview_manager = ListViewManager.new @listview, self
        @iconview_manager = IconViewManager.new @iconview, self
        @sidepane_manager = SidePaneManager.new @library_listview, self
        @library_listview = @sidepane_manager.library_listview
        @listview_manager.setup_listview_columns_visibility
        @listview_manager.setup_listview_columns_width
      end

      def setup_callbacks
        self.class.send(:include, Callbacks)
        connect_signals
      end

      def get_preferences
        @prefs = Preferences.instance
      end

      def setup_toolbar
        log.debug { "setup_toolbar" }
        setup_book_providers
        add_main_toolbar_items
        @toolbar = @uimanager.get_widget("/MainToolbar")
        @toolbar.show_arrow = true
        @toolbar.insert(Gtk::SeparatorToolItem.new, -1)
        setup_toolbar_combobox
        setup_toolbar_filter_entry
        @toolbar.insert(Gtk::SeparatorToolItem.new, -1)
        setup_toolbar_viewas
        @toolbar.show_all
        @actiongroup["Undo"].sensitive = @actiongroup["Redo"].sensitive = false
        UndoManager.instance.add_observer(self)
        @vbox1.add(@toolbar, position: 1, expand: false, fill: false)
      end

      def add_main_toolbar_items
        mid = @uimanager.new_merge_id
        @uimanager.add_ui(mid, "ui/", "MainToolbar", "MainToolbar",
                          :toolbar, false)
        @uimanager.add_ui(mid, "ui/MainToolbar/", "New", "New",
                          :toolitem, false)
        @uimanager.add_ui(mid, "ui/MainToolbar/", "AddBook", "AddBook",
                          :toolitem, false)
        # @uimanager.add_ui(mid, "ui/MainToolbar/", "sep", "sep",
        #                  :separator, false)
        # @uimanager.add_ui(mid, "ui/MainToolbar/", "Refresh", "Refresh",
        #                  :toolitem, false)
      end

      def setup_toolbar_filter_entry
        @filter_entry = Gtk::Entry.new
        @filter_entry.signal_connect("changed", &method(:on_toolbar_filter_entry_changed))
        @toolitem = Gtk::ToolItem.new
        @toolitem.expand = true
        @toolitem.border_width = 5
        @filter_entry.set_tooltip_text _("Type here the search criterion")
        @toolitem << @filter_entry
        @toolbar.insert(@toolitem, -1)
      end

      def setup_toolbar_combobox
        cb = Gtk::ComboBoxText.new
        cb.set_row_separator_func do |model, iter|
          # TODO: Replace with iter[0] if possible
          model.get_value(iter, 0) == "-"
        end
        [_("Match everything"),
         "-",
         _("Title contains"),
         _("Authors contain"),
         _("ISBN contains"),
         _("Publisher contains"),
         _("Notes contain"),
         _("Tags contain")].each do |item|
          cb.append_text(item)
        end
        cb.active = 0
        cb.signal_connect("changed", &method(:on_criterion_combobox_changed))

        # Put the combo box in a event box because it is not currently
        # possible assign a tooltip to a combo box.
        eb = Gtk::EventBox.new
        eb << cb
        @toolitem = Gtk::ToolItem.new
        @toolitem.border_width = 5
        @toolitem << eb
        @toolbar.insert(@toolitem, -1)
        eb.set_tooltip_text _("Change the search type")
      end

      def setup_toolbar_viewas
        @toolbar_view_as = Gtk::ComboBoxText.new
        @toolbar_view_as.append_text(_("View as Icons"))
        @toolbar_view_as.append_text(_("View as List"))
        @toolbar_view_as.active = 0
        @toolbar_view_as_signal_hid = \
          @toolbar_view_as.signal_connect("changed", &method(:on_toolbar_view_as_changed))

        # Put the combo box in a event box because it is not currently
        # possible assign a tooltip to a combo box.
        eb = Gtk::EventBox.new
        eb << @toolbar_view_as
        @toolitem = Gtk::ToolItem.new
        @toolitem.border_width = 5
        @toolitem << eb
        @toolbar.insert(@toolitem, -1)
        eb.set_tooltip_text _("Choose how to show books")
      end

      def setup_book_providers
        log.debug { "setup_book_providers" }
        mid = @uimanager.new_merge_id
        BookProviders.each do |provider|
          name = provider.action_name
          ["ui/MainMenubar/ViewMenu/OnlineInformation/",
           "ui/BookPopup/OnlineInformation/",
           "ui/NoBookPopup/OnlineInformation/"].each do |path|
             log.debug { "Adding #{name} to #{path}" }
             @uimanager.add_ui(mid, path, name, name,
                               :menuitem, false)
           end
        end
      end

      def add_menus_and_popups_from_xml
        log.debug { "add_menus_and_popups_from_xml" }
        ["menus.xml", "popups.xml"].each do |ui_file|
          @uimanager.add_ui(File.join(Alexandria::Config::DATA_DIR,
                                      "ui", ui_file))
        end
      end

      def setup_accel_group
        log.debug { "setup_accel_group" }
        @main_app.add_accel_group(@uimanager.accel_group)
      end

      def setup_menus
        @menubar = @uimanager.get_widget("/MainMenubar")
        @vbox1.add(@menubar, position: 0, expand: false, fill: false)
      end

      def setup_popups
        log.debug { "setup_popups" }
        @library_popup = @uimanager.get_widget("/LibraryPopup")
        @smart_library_popup = @uimanager.get_widget("/SmartLibraryPopup")
        @nolibrary_popup = @uimanager.get_widget("/NoLibraryPopup")
        @book_popup = @uimanager.get_widget("/BookPopup")
        @nobook_popup = @uimanager.get_widget("/NoBookPopup")
      end

      def setup_window_events
        log.debug { "setup_window_events" }
        @main_app.signal_connect("window-state-event", &method(:on_window_state_event))
        @main_app.signal_connect("destroy", &method(:on_window_destroy))
      end

      def setup_active_model
        log.debug { "setting up active model" }
        # The active model.

        list = [
          GdkPixbuf::Pixbuf,    # COVER_LIST
          GdkPixbuf::Pixbuf,    # COVER_ICON
          String,         # TITLE
          String,         # TITLE_REDUCED
          String,         # AUTHORS
          String,         # ISBN
          String,         # PUBLISHER
          String,         # PUBLISH_DATE
          String,         # EDITION
          Integer,        # RATING
          String,         # IDENT
          String,         # NOTES
          TrueClass,      # REDD
          TrueClass,      # OWN
          TrueClass,      # WANT
          String,         # TAGS
          String          # LOANED TO
        ]

        @model = Gtk::ListStore.new(*list)

        # Filter books according to the search toolbar widgets.
        @filtered_model = Gtk::TreeModelFilter.new(@model)
        @filtered_model.set_visible_func do |_model, iter|
          # log.debug { "visible_func" }
          @filter_books_mode ||= 0
          filter = @filter_entry.text
          if filter.empty?
            true
          else
            data = case @filter_books_mode
                   when 0
                     (iter[Columns::TITLE] || "") +
                       (iter[Columns::AUTHORS] || "") +
                       (iter[Columns::ISBN] || "") +
                       (iter[Columns::PUBLISHER] || "") +
                       (iter[Columns::NOTES] || "") +
                       (iter[Columns::TAGS] || "")
                   when 2 then iter[Columns::TITLE]
                   when 3 then iter[Columns::AUTHORS]
                   when 4 then iter[Columns::ISBN]
                   when 5 then iter[Columns::PUBLISHER]
                   when 6 then iter[Columns::NOTES]
                   when 7 then iter[Columns::TAGS]
                   end
            !data.nil? && data.downcase.include?(filter.downcase)
          end
        end

        # Give filter entry the initial keyboard focus.
        @filter_entry.grab_focus
        log.debug { "done setting up active model" }
      end

      def on_library_button_press_event(widget, event)
        log.debug { "library_button_press_event" }

        # right click
        if event_is_right_click event
          log.debug { "library right click!" }
          library_already_selected = true
          if (path = widget.get_path_at_pos(event.x, event.y))
            @clicking_on_sidepane = true
            obj, path =
              widget.is_a?(Gtk::TreeView) ? [widget.selection, path.first] : [widget, path]
            widget.has_focus = true

            unless obj.path_is_selected?(path)

              log.debug { "Select #{path}" }
              library_already_selected = false
              widget.unselect_all
              obj.select_path(path)
              sensitize_library selected_library

              if widget.is_a?(Gtk::TreeView)
                GLib::Idle.add do
                  # cur_path, focus_col = widget.cursor

                  widget.focus = true

                  widget.set_cursor(path, nil, false)
                  widget.grab_focus
                  widget.has_focus = true
                  false
                end
                # widget.has_focus = true
              end

              # library_already_selected = true
            end
          else
            widget.unselect_all
          end

          menu = determine_library_popup widget, event

          # Fixes part of bug #25021.
          #
          # If the library was not selected when it was right-clicked
          # we should select the library first (we call on_focus
          # manually, since the above call to obj.select_path(path) doesn't
          # seem to suffice).
          #
          # Then we wait a while and only *then* pop up the menu.
          sensitize_library selected_library if library_already_selected

          GLib::Idle.add do
            menu.popup(nil, nil, event.button, event.time)
            false
          end

          # not a right click
        elsif (path = widget.get_path_at_pos(event.x, event.y))
          @clicking_on_sidepane = true
          obj, path =
            widget.is_a?(Gtk::TreeView) ? [widget.selection, path.first] : [widget, path]
          obj.select_path(path)
          sensitize_library selected_library
        end
      end

      def determine_library_popup(widget, event)
        if widget.get_path_at_pos(event.x, event.y).nil?
          @nolibrary_popup
        elsif selected_library.is_a?(SmartLibrary)
          @smart_library_popup
        else
          @library_popup
        end
      end

      def event_is_right_click(event)
        (event.event_type == :button_press) && (event.button == 3)
      end

      def on_books_button_press_event(widget, event)
        log.debug { "books_button_press_event" }
        if event_is_right_click event
          widget.grab_focus

          if (path = widget.get_path_at_pos(event.x.to_i, event.y.to_i))
            obj, path =
              widget.is_a?(Gtk::TreeView) ? [widget.selection, path.first] : [widget, path]

            unless obj.path_is_selected?(path)
              log.debug { "Select #{path}" }
              widget.unselect_all
              obj.select_path(path)
            end
          else
            widget.unselect_all
          end

          menu = selected_books.empty? ? @nobook_popup : @book_popup
          menu.popup(nil, nil, event.button, event.time)
        end
      end

      def get_library_selection_text(library)
        case library.length
        when 0
          _("Library '%s' selected") % library.name

        else
          n_unrated = library.n_unrated
          if n_unrated == library.length
            format(n_("Library '%s' selected, %d unrated book",
                      "Library '%s' selected, %d unrated books",
                      library.length), library.name, library.length)
          elsif n_unrated.zero?
            format(n_("Library '%s' selected, %d book",
                      "Library '%s' selected, %d books",
                      library.length), library.name, library.length)
          else
            format(n_("Library '%s' selected, %d book, " \
               "%d unrated",
                      "Library '%s' selected, %d books, " \
                      "%d unrated",
                      library.length), library.name, library.length, n_unrated)
          end
        end
      end

      def get_appbar_status(library, books)
        case books.length
        when 0
          get_library_selection_text library
        when 1
          _("'%s' selected") % books.first.title
        else
          n_("%d book selected", "%d books selected",
             books.length) % books.length
        end
      end

      def set_status_label(txt)
        @status_label.text = txt
      end

      def on_books_selection_changed
        library = selected_library
        books = selected_books
        set_status_label(get_appbar_status(library, books))

        # Focus is the wrong idiom here.
        unless @clicking_on_sidepane || (@main_app.focus == @library_listview)
          # unless @main_app.focus == @library_listview

          log.debug { "Currently focused widget: #{@main_app.focus.inspect}" }
          log.debug { "#{@library_listview} : #{@library_popup} : #{@listview}" }
          log.debug do
            "@library_listview: #{@library_listview.has_focus?} " \
            "or @library_popup:#{@library_popup.has_focus?}"
          end
          log.debug { "@library_listview does *NOT* have focus" }
          log.debug { "Books are empty: #{books.empty?}" }
          @actiongroup["Properties"].sensitive = \
            @actiongroup["OnlineInformation"].sensitive = \
              books.length == 1
          @actiongroup["SelectAll"].sensitive = \
            books.length < library.length

          @actiongroup["Delete"].sensitive = \
            @actiongroup["DeselectAll"].sensitive = \
              @actiongroup["Move"].sensitive =
                @actiongroup["SetRating"].sensitive = !books.empty?

          log.debug do
            "on_books_selection_changed Delete: #{@actiongroup['Delete'].sensitive?}"
          end

          if library.is_a?(SmartLibrary)
            @actiongroup["Delete"].sensitive =
              @actiongroup["Move"].sensitive = false
          end

          # Sensitize providers URL
          if books.length == 1
            b = books.first
            # FIXME: Clean up endless negation in this logic
            no_urls = true
            BookProviders.each do |provider|
              has_no_url = true
              begin
                has_no_url = (b.isbn.nil? || b.isbn.strip.empty? || provider.url(b).nil?)
              rescue StandardError => ex
                log.warn { "Error determining URL from #{provider.name}; #{ex.message}" }
              end
              @actiongroup[provider.action_name].sensitive = !has_no_url
              no_urls = false unless has_no_url
            end
            @actiongroup["OnlineInformation"].sensitive = false if no_urls
          end
        end
        @clicking_on_sidepane = false
      end

      def on_switch_page(_notebook, _page, page_num)
        log.debug { "on_switch_page" }
        @actiongroup["ArrangeIcons"].sensitive = page_num.zero?
        on_books_selection_changed
      end

      def on_focus(widget, _event_focus)
        if @clicking_on_sidepane || (widget == @library_listview)
          log.debug { "on_focus: @library_listview" }
          GLib::Idle.add do
            %w(OnlineInformation SelectAll DeselectAll).each do |action|
              @actiongroup[action].sensitive = false
            end
            @actiongroup["Properties"].sensitive = selected_library.is_a?(SmartLibrary)
            @actiongroup["Delete"].sensitive = determine_delete_option
            false
          end
        else
          on_books_selection_changed
        end
      end

      def determine_delete_option
        @libraries.all_regular_libraries.length > 1 || selected_library.is_a?(SmartLibrary)
      end

      def on_close_sidepane
        log.debug { "on_close_sidepane" }
        @actiongroup["Sidepane"].active = false
      end

      def select_a_book(book)
        select_this_book = proc do |bk, view|
          @filtered_model.refilter
          iter = iter_from_book bk
          next unless iter

          path = iter.path
          next unless view.model

          path = view_path_to_model_path(view, path)
          log.debug { "Path for #{bk.ident} is #{path}" }
          selection = view.respond_to?(:selection) ? @listview.selection : @iconview
          selection.unselect_all
          selection.select_path(path)
        end
        begin
          log.debug { "select_a_book: listview" }
          select_this_book.call(book, @listview)
          log.debug { "select_a_book: listview" }
          select_this_book.call(book, @iconview)
        rescue StandardError => ex
          trace = ex.backtrace.join("\n> ")
          log.warn { "Failed to automatically select book: #{ex.message} #{trace}" }
        end
        # TODO: Figure out why this frequently selects the wrong book!
      end

      def update(*ary)
        log.debug { "on_update #{ary}" }
        caller = ary.first
        if caller.is_a?(UndoManager)
          @actiongroup["Undo"].sensitive = caller.can_undo?
          @actiongroup["Redo"].sensitive = caller.can_redo?
        elsif caller.is_a?(Library)
          handle_update_caller_library ary unless caller.updating?
        else
          raise _("unrecognized update event")
        end
      end

      def handle_update_caller_library(ary)
        library, kind, book = ary
        if library == selected_library
          @iconview.freeze # This makes @iconview.model == nil
          @listview.freeze # NEW
          case kind
          when Library::BOOK_ADDED
            append_book(book)
          when Library::BOOK_UPDATED
            iter = iter_from_ident(book.saved_ident)
            fill_iter_with_book(iter, book) if iter
          when Library::BOOK_REMOVED
            @model.remove(iter_from_book(book))
          end
          @iconview.unfreeze
          @listview.unfreeze # NEW
          select_a_book(book) if [Library::BOOK_ADDED, Library::BOOK_UPDATED].include? kind
        elsif selected_library.is_a?(SmartLibrary)
          refresh_books
        end
      end

      # private

      def open_web_browser(url)
        if url.nil?
          log.warn("Attempt to open browser with nil url")
          return
        end
        Gtk.show_uri url
      end

      def detach_old_libraries
        log.debug { "Un-observing old libraries" }
        @libraries.all_regular_libraries.each do |library|
          if library.is_a?(Library)
            library.delete_observer(self)
            @completion_models.remove_source(library)
          end
        end
      end

      def load_libraries
        log.info { "Loading libraries..." }
        @completion_models = CompletionModels.instance
        if @libraries
          detach_old_libraries
          @libraries.reload
        else
          @libraries = LibraryCollection.instance
          @libraries.reload
          handle_ruined_books unless @libraries.ruined_books.empty?
        end
        @libraries.all_regular_libraries.each do |library|
          library.add_observer(self)
          @completion_models.add_source(library)
        end
      end

      def handle_ruined_books
        new_message = _(
          "The data files for the following books are malformed or empty. Do you wish to" \
          " attempt to download new information for them from the online book providers?\n")

        @libraries.ruined_books.each do |bi|
          new_message += "\n#{bi[1] || bi[1].inspect}"
        end
        recovery_dialog = Gtk::MessageDialog.new(@main_app, Gtk::Dialog::MODAL,
                                                 Gtk::MessageDialog::WARNING,
                                                 Gtk::MessageDialog::BUTTONS_OK_CANCEL,
                                                 new_message).show
        recovery_dialog.signal_connect("response") do |_dialog, response_type|
          recovery_dialog.destroy
          if response_type == Gtk::ResponseType::OK
            # progress indicator...
            @progressbar.fraction = 0
            @appbar.children.first.visible = true # show the progress bar

            total_book_count = @libraries.ruined_books.size
            fraction_per_book = 1.0 / total_book_count
            prog_percentage = 0

            @libraries.ruined_books.reverse!
            GLib::Idle.add do
              ruined_book = @libraries.ruined_books.pop
              if ruined_book
                book, isbn, library = ruined_book
                begin
                  book_rslt = Alexandria::BookProviders.isbn_search(isbn.to_s)
                  book = book_rslt[0]
                  cover_uri = book_rslt[1]

                  # TODO: if the book was saved okay, make sure the old
                  # empty yaml file doesn't stick around esp if doing
                  # isbn-10 --> isbn-13 conversion...
                  if isbn.size == 10
                    filename = library.yaml(isbn)
                    log.debug { "removing old file #{filename}" }
                    begin
                      File.delete(filename)
                    rescue StandardError => ex
                      log.error { "Could not delete empty file #{filename}" }
                    end
                  end

                  log.debug do
                    "Trying to add #{book.title}, #{cover_uri}" \
                    " in library ''#{library.name}'"
                  end
                  library.save_cover(book, cover_uri) unless cover_uri.nil?
                  library << book
                  library.save(book)
                  set_status_label(format(_("Added '%s' to library '%s'"),
                                          book.title, library.name))
                rescue StandardError => ex
                  log.error { "Couldn't add book #{isbn}: #{ex}" }
                  log.error { ex.backtrace.join("\n") }
                end

                prog_percentage += fraction_per_book
                @progressbar.fraction = prog_percentage

                true
              else
                ## Totally copied and pasted from refresh_books...
                ## call this the second strike... (CathalMagus)

                # @iconview.unfreeze
                # @filtered_model.refilter
                # @listview.columns_autosize

                @progressbar.fraction = 1
                ## Hide the progress bar.
                @appbar.children.first.visible = false
                ## Refresh the status bar.
                set_status_label("")
                # on_books_selection_changed
                false
              end
            end
          end
        end
      end

      def cache_scaled_icon(icon, width, height)
        log.debug { "cache_scaled_icon #{icon}, #{width}, #{height}" }
        @cache ||= {}
        @cache[[icon, width, height]] ||= icon.scale(width, height)
      end

      ICON_TITLE_MAXLEN = 20   # characters
      ICON_HEIGHT = 90         # pixels
      REDUCE_TITLE_REGEX = Regexp.new("^(.{#{ICON_TITLE_MAXLEN}}).*$")

      def fill_iter_with_book(iter, book)
        log.debug { "fill iter #{iter} with book #{book}" }
        iter[Columns::IDENT] = book.ident.to_s
        iter[Columns::TITLE] = book.title
        title = book.title.sub(REDUCE_TITLE_REGEX, '\1...')
        iter[Columns::TITLE_REDUCED] = title
        iter[Columns::AUTHORS] = book.authors.join(", ")
        iter[Columns::ISBN] = book.isbn.to_s
        iter[Columns::PUBLISHER] = book.publisher
        iter[Columns::PUBLISH_DATE] = book.publishing_year.to_s
        iter[Columns::EDITION] = book.edition
        iter[Columns::NOTES] = (book.notes || "")
        iter[Columns::LOANED_TO] = (book.loaned_to || "")
        rating = (book.rating || Book::DEFAULT_RATING)
        # ascending order is the default
        iter[Columns::RATING] = Book::MAX_RATING_STARS - rating
        iter[Columns::OWN] = book.own?
        iter[Columns::REDD] = book.redd?
        iter[Columns::WANT] = book.want?
        iter[Columns::TAGS] = if book.tags
                                book.tags.join(",")
                              else
                                ""
                              end

        icon = Icons.cover(selected_library, book)
        log.debug { "Setting icon #{icon} for book #{book.title}" }
        iter[Columns::COVER_LIST] = cache_scaled_icon(icon, 20, 25)

        if icon.height > ICON_HEIGHT
          new_width = icon.width / (icon.height / ICON_HEIGHT.to_f)
          new_height = [ICON_HEIGHT, icon.height].min
          icon = cache_scaled_icon(icon, new_width, new_height)
        end
        icon = icon.tag(Icons::FAVORITE_TAG) if rating == Book::MAX_RATING_STARS
        iter[Columns::COVER_ICON] = icon
        log.debug { "Full iter: " + (0..15).map { |num| iter[num].inspect }.join(", ") }
      end

      def append_book(book, _tail = nil)
        log.debug { @model.inspect }
        iter = @model.append
        log.debug { "iter == #{iter}" }
        if iter
          fill_iter_with_book(iter, book)
        else
          log.debug { "@model.append" }
          iter = @model.append
          fill_iter_with_book(iter, book)
          log.debug { "no iter for book #{book}" }
        end
        library = selected_library
        if library.deleted_books.include?(book)
          log.debug { "Stop! Don't delete this book! We re-added it!" }
          library.undelete(book)
          UndoManager.instance.push { undoable_delete(library, [book]) }
        end
        iter
      end

      def append_library(library, autoselect = false)
        log.debug { "append_library #{library.name}" }
        model = @library_listview.model
        is_smart = library.is_a?(SmartLibrary)
        if is_smart
          @library_separator_iter = append_library_separator if @library_separator_iter.nil?
          iter = model.append
        else
          iter = if @library_separator_iter.nil?
                   model.append
                 else
                   model.insert_before(@library_separator_iter)
                 end
        end

        iter[0] = is_smart ? Icons::SMART_LIBRARY_SMALL : Icons::LIBRARY_SMALL
        iter[1] = library.name
        iter[2] = true      # editable?
        iter[3] = false     # separator?
        if autoselect
          @library_listview.set_cursor(iter.path,
                                       @library_listview.get_column(0),
                                       true)
          @actiongroup["Sidepane"].active = true
        end
        iter
      end

      def append_library_separator
        log.debug { "append_library_separator" }
        iter = @library_listview.model.append
        iter[0] = nil
        iter[1] = nil
        iter[2] = false     # editable?
        iter[3] = true      # separator?
        iter
      end

      def refresh_books
        log.debug { "refresh_books" }
        @library_listview.set_sensitive(false)
        library = selected_library
        @iconview.freeze
        @listview.freeze
        @model.clear
        @progressbar.fraction = 0
        @appbar.children.first.visible = true # show the progress bar
        set_status_label(_("Loading '%s'...") % library.name)
        total = library.length
        log.debug { "library #{library.name} length #{library.length}" }
        n = 0

        GLib::Idle.add do
          block_return = true
          book = library[n]
          if book
            begin
              append_book(book)
            rescue StandardError => ex
              trace = ex.backtrace.join("\n > ")
              log.error { "append_books failed #{ex.message} #{trace}" }
            end
            fraction = n * 1.0 / total
            log.debug { "#index #{n} fraction #{fraction}" }
            @progressbar.fraction = fraction
            n += 1
          else
            @iconview.unfreeze
            @listview.unfreeze # NEW / bdewey
            @filtered_model.refilter
            @listview.columns_autosize
            @progressbar.fraction = 1
            # Hide the progress bar.
            @appbar.children.first.visible = false
            # Refresh the status bar.
            on_books_selection_changed
            @library_listview.set_sensitive(true)
            block_return = false
          end

          block_return
        end
      end

      def selected_library
        log.debug { "selected_library" }
        if (iter = @library_listview.selection.selected)
          target_name = iter[1]
          @libraries.all_libraries.find { |it| it.name == target_name }
        else
          @libraries.all_libraries.first
        end
      end

      def select_library(library)
        log.debug { "select library #{library}" }
        iter = @library_listview.model.iter_first
        ok = true
        while ok
          if iter[1] == library.name
            @library_listview.selection.select_iter(iter)
            break
          end
          ok = iter.next!
        end
      end

      def book_from_iter(library, iter)
        log.debug { "Book from iter: #{library} #{iter}" }
        library.find { |x| x.ident == iter[Columns::IDENT] }
      end

      def iter_from_ident(ident)
        log.debug { ident.to_s }
        iter = @model.iter_first
        ok = true
        while ok
          return iter if iter[Columns::IDENT] == ident

          ok = iter.next!
        end
        nil
      end

      def iter_from_book(book)
        log.debug { book.to_s }
        iter_from_ident(book.ident)
      end

      def collate_selected_books(page)
        result = []
        library = selected_library

        if page.zero?
          result = @iconview.selected_items.map do |path|
            path = view_path_to_model_path(@iconview, path)
            book_from_iter(library, @model.get_iter(path))
          end
        else
          selection = @listview.selection
          rows, _model = selection.selected_rows
          result = rows.map do |path|
            path = view_path_to_model_path(@listview, path)
            book_from_iter(library, @model.get_iter(path))
          end
        end

        result
      end

      def selected_books
        selected = collate_selected_books(@notebook.page).compact
        log.debug { "Selected books = #{selected.inspect}" }
        selected
      end

      def refresh_libraries
        log.debug { "refresh_libraries" }
        library = selected_library

        # Change the application's title.
        @main_app.title = library.name + " - " + TITLE

        # Disable the selected library in the move libraries actions.
        @libraries.all_regular_libraries.each do |i_library|
          action = @actiongroup[i_library.action_name]
          action.sensitive = i_library != library if action
        end
        sensitize_library library
      end

      def sensitize_library(library)
        smart = library.is_a?(SmartLibrary)
        log.debug { "sensitize_library: smartlibrary = #{smart}" }
        GLib::Idle.add do
          @actiongroup["AddBook"].sensitive = !smart
          @actiongroup["AddBookManual"].sensitive = !smart
          @actiongroup["Properties"].sensitive = smart
          can_delete = smart || (@libraries.all_regular_libraries.length > 1)
          @actiongroup["Delete"].sensitive = can_delete
          log.debug { "sensitize_library delete: #{@actiongroup['Delete'].sensitive?}" }
          false
        end
      end

      def get_view_actiongroup
        case @prefs.view_as
        when 0
          @actiongroup["AsIcons"]
        when 1
          @actiongroup["AsList"]
        end
      end

      def restore_preferences
        log.debug { "Restoring preferences..." }
        if @prefs.maximized
          @main_app.maximize
        else
          @main_app.move(*@prefs.position) unless @prefs.position == [0, 0]
          @main_app.resize(*@prefs.size)
          @maximized = false
        end
        @paned.position = @prefs.sidepane_position
        @actiongroup["Sidepane"].active = @prefs.sidepane_visible
        @actiongroup["Toolbar"].active = @prefs.toolbar_visible
        @actiongroup["Statusbar"].active = @prefs.statusbar_visible
        @appbar.visible = @prefs.statusbar_visible
        action = get_view_actiongroup
        action.activate
        library = nil
        unless @prefs.selected_library.nil?
          library = @libraries.all_libraries.find do |x|
            x.name == @prefs.selected_library
          end
        end
        select_a_library library
      end

      def select_a_library(library)
        if library
          select_library(library)
        else
          # Select the first item by default.
          iter = @library_listview.model.iter_first
          @library_listview.selection.select_iter(iter)
        end
      end

      def save_preferences
        log.debug { "save_preferences" }
        @prefs.position = @main_app.position
        @prefs.size = @main_app.allocation.to_a[2..3]
        @prefs.maximized = @maximized
        @prefs.sidepane_position = @paned.position
        @prefs.sidepane_visible = @actiongroup["Sidepane"].active?
        @prefs.toolbar_visible = @actiongroup["Toolbar"].active?
        @prefs.statusbar_visible = @actiongroup["Statusbar"].active?
        @prefs.view_as = @notebook.page
        @prefs.selected_library = selected_library.name
        cols_width = {}
        @listview.columns.each do |c|
          cols_width[c.title] = c.width
        end
        @prefs.cols_width = "{" + cols_width.to_a.map do |t, v|
          '"' + t + '": ' + v.to_s
        end.join(", ") + "}"
        log.debug { "cols_width: #{@prefs.cols_width} " }
        @prefs.save!
      end

      def undoable_move(source, dest, books)
        log.debug { "undoable_move" }
        Library.move(source, dest, *books)
        UndoManager.instance.push { undoable_move(dest, source, books) }
      end

      def move_selected_books_to_library(library)
        books = selected_books.select do |book|
          !library.include?(book) ||
            ConflictWhileCopyingDialog.new(@main_app,
                                           library,
                                           book).replace?
        end
        undoable_move(selected_library, library, books)
      end

      def setup_move_actions
        @actiongroup.actions.each do |action|
          next unless /^MoveIn/.match?(action.name)

          @actiongroup.remove_action(action)
        end
        actions = []
        @libraries.all_regular_libraries.each do |library|
          actions << [
            library.action_name, nil,
            _("In '_%s'") % library.name,
            nil, nil, proc { move_selected_books_to_library(library) }
          ]
        end
        @actiongroup.add_actions(actions)
        @uimanager.remove_ui(@move_mid) if @move_mid
        @move_mid = @uimanager.new_merge_id
        @libraries.all_regular_libraries.each do |library|
          name = library.action_name
          ["ui/MainMenubar/EditMenu/Move/",
           "ui/BookPopup/Move/"].each do |path|
            @uimanager.add_ui(@move_mid, path, name, name,
                              :menuitem, false)
          end
        end
      end

      def current_view
        case @notebook.page
        when 0
          @iconview
        when 1
          @listview
        end
      end

      # Gets the sort order of the current library, for use by export
      def library_sort_order
        # added by Cathal Mc Ginley, 23 Oct 2007
        log.debug do
          "library_sort_order #{@notebook.page}: " \
          "#{@iconview.model.inspect} #{@listview.model.inspect}"
        end
        result, sort_column, sort_order = current_view.model.sort_column_id
        if result
          column_ids_to_attributes = { 2  => :title,
                                       4  => :authors,
                                       5  => :isbn,
                                       6  => :publisher,
                                       7  => :publishing_year,
                                       8  => :edition, # binding
                                       12 => :redd,
                                       13 => :own,
                                       14 => :want,
                                       9  => :rating }

          sort_attribute = column_ids_to_attributes.fetch sort_column
          ascending = (sort_order == :ascending)
          LibrarySortOrder.new(sort_attribute, ascending)
        else
          LibrarySortOrder::Unsorted.new
        end
      end

      def get_previous_selected_library(library)
        log.debug { "get_previous_selected_library: #{library}" }
        @previous_selected_library = selected_library
        if @previous_selected_library != library
          select_library(library)
        else
          @previous_selected_library = nil
        end
      end

      def remove_library_iter
        old_iter = @library_listview.selection.selected
        # commenting out this code seems to fix #20681
        # "crashes when switching to smart library mid-load"
        # next_iter = @library_listview.selection.selected
        # next_iter.next!
        @library_listview.model.remove(old_iter)
        # @library_listview.selection.select_iter(next_iter)
      end

      def undoable_delete(library, books = nil)
        # Deleting a library.
        if books.nil?
          library.delete_observer(self) if library.is_a?(Library)
          library.delete
          @libraries.remove_library(library)
          remove_library_separator
          remove_library_iter
          get_previous_selected_library library
          setup_move_actions
          select_library(@previous_selected_library) unless @previous_selected_library.nil?
          @previous_selected_library = nil
        else
          # Deleting books.
          books.each { |book| library.delete(book) }
        end
        UndoManager.instance.push { undoable_undelete(library, books) }
      end

      def remove_library_separator
        if !@library_separator_iter.nil? && @libraries.all_smart_libraries.empty?
          @library_listview.model.remove(@library_separator_iter)
          @library_separator_iter = nil
        end
      end

      def undoable_undelete(library, books = nil)
        # Undeleting a library.
        if books.nil?
          library.undelete
          @libraries.add_library(library)
          append_library(library)
          setup_move_actions
          library.add_observer(self) if library.is_a?(Library)
          # Undeleting books.
        else
          books.each { |book| library.undelete(book) }
        end
        select_library(library)
        UndoManager.instance.push { undoable_delete(library, books) }
      end

      def setup_window_icons
        @main_app.icon = Icons::ALEXANDRIA_SMALL
        Gtk::Window.set_default_icon_name("alexandria")
        @main_app.icon_name = "alexandria"
      end

      ICONS_SORTS = [
        Columns::TITLE, Columns::AUTHORS, Columns::ISBN,
        Columns::PUBLISHER, Columns::EDITION, Columns::RATING,
        Columns::REDD, Columns::OWN, Columns::WANT
      ].freeze

      def setup_books_iconview_sorting
        sort_order = @prefs.reverse_icons ? :descending : :ascending
        mode = ICONS_SORTS[@prefs.arrange_icons_mode]
        @iconview_model.set_sort_column_id(mode, sort_order)
        @filtered_model.refilter # force redraw
      end

      private

      def view_path_to_model_path(view, path)
        path = view.model.convert_path_to_child_path(path)
        @filtered_model.convert_path_to_child_path(path) if path
      end
    end
  end
end
