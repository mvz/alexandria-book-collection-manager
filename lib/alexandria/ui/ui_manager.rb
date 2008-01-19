module Alexandria
  module UI
    MAX_RATING_STARS = 5
    class UIManager < GladeBase
      attr_accessor :main_app, :actiongroup, :appbar, :prefs, :listview, :iconview, :listview_model,
        :iconview_model, :filtered_model, :on_books_selection_changed
      include Logging
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

      module Columns
        COVER_LIST, COVER_ICON, TITLE, TITLE_REDUCED, AUTHORS,
          ISBN, PUBLISHER, PUBLISH_DATE, EDITION, RATING, IDENT,
          NOTES, REDD, OWN, WANT, TAGS = (0..16).to_a
      end

      # The maximum number of rating stars displayed.
      MAX_RATING_STARS = 5

      def initialize parent
        super("main_app.glade")
        @parent = parent
        get_preferences
        load_libraries
        setup_window_icons
        setup_callbacks
        create_uimanager
        setup_toolbar
        setup_move_actions
        setup_active_model
        setup_dependents  
        setup_accel_group
        add_menus_and_popups_from_xml 
        setup_menus
        setup_popups
        setup_window_events 
        setup_dialog_hooks
        setup_books_iconview_sorting
        on_books_selection_changed
        restore_preferences
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
        require 'alexandria/ui/callbacks'
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
        @toolbar.insert(-1, Gtk::SeparatorToolItem.new)
        setup_toolbar_combobox 
        setup_toolbar_filter_entry
        @toolbar.insert(-1, Gtk::SeparatorToolItem.new)
        setup_toolbar_viewas
        @toolbar.show_all
        @actiongroup["Undo"].sensitive = @actiongroup["Redo"].sensitive = false
        UndoManager.instance.add_observer(self)
        log.debug { "Connect ui elements to mainapp." }
        @main_app.toolbar = @toolbar
      end

      def add_main_toolbar_items
        mid = @uimanager.new_merge_id
        @uimanager.add_ui(mid, "ui/", "MainToolbar", "MainToolbar",
                          Gtk::UIManager::TOOLBAR, false)
        @uimanager.add_ui(mid, "ui/MainToolbar/", "New", "New",
                          Gtk::UIManager::TOOLITEM, false)
        @uimanager.add_ui(mid, "ui/MainToolbar/", "AddBook", "AddBook",
                          Gtk::UIManager::TOOLITEM, false)
        @uimanager.add_ui(mid, "ui/MainToolbar/", "sep", "sep",
                          Gtk::UIManager::SEPARATOR, false)
        @uimanager.add_ui(mid, "ui/MainToolbar/", "Refresh", "Refresh",
                          Gtk::UIManager::TOOLITEM, false)
      end

      def setup_toolbar_filter_entry
        @filter_entry = Gtk::Entry.new
        @filter_entry.signal_connect('changed', &method(:on_toolbar_filter_entry_changed))        
        @toolitem = Gtk::ToolItem.new
        @toolitem.expand = true
        @toolitem.border_width = 5
        @tooltips.set_tip(@filter_entry,
                          _("Type here the search criterion"), nil)
        @toolitem << @filter_entry
        @toolbar.insert(-1, @toolitem)
      end

      def setup_toolbar_combobox
        @tooltips = Gtk::Tooltips.new

        cb = Gtk::ComboBox.new
        cb.set_row_separator_func do |model, iter|
          #log.debug { "row_separator" }
          iter[0] == '-'
        end
        [ _("Match everything"),
              '-',
              _("Title contains"),
              _("Authors contain"),
              _("ISBN contains"),
              _("Publisher contains"),
              _("Notes contain"),
              _("Tags contain")
        ].each do |item|
          cb.append_text(item)
        end
        cb.active = 0
        cb.signal_connect('changed', &method(:on_criterion_combobox_changed))

        # Put the combo box in a event box because it is not currently
        # possible assign a tooltip to a combo box.
        eb = Gtk::EventBox.new
        eb << cb
        @toolitem = Gtk::ToolItem.new
        @toolitem.border_width = 5
        @toolitem << eb
        @toolbar.insert(-1, @toolitem)
        @tooltips.set_tip(eb, _("Change the search type"), nil)
      end

      def setup_toolbar_viewas
        @toolbar_view_as = Gtk::ComboBox.new
        @toolbar_view_as.append_text(_("View as Icons"))
        @toolbar_view_as.append_text(_("View as List"))
        @toolbar_view_as.active = 0
        @toolbar_view_as_signal_hid = \
          @toolbar_view_as.signal_connect('changed', &method(:on_toolbar_view_as_changed))      
 
        # Put the combo box in a event box because it is not currently
        # possible assign a tooltip to a combo box.
        eb = Gtk::EventBox.new
        eb << @toolbar_view_as
        @toolitem = Gtk::ToolItem.new
        @toolitem.border_width = 5
        @toolitem << eb
        @toolbar.insert(-1, @toolitem)
        @tooltips.set_tip(eb, _("Choose how to show books"), nil)
      end

      def setup_book_providers
        mid = @uimanager.new_merge_id
        BookProviders.each do |provider|
          name = provider.action_name
          [ "ui/MainMenubar/ViewMenu/OnlineInformation/",
                "ui/BookPopup/OnlineInformation/",
                "ui/NoBookPopup/OnlineInformation/" ].each do |path|
            @uimanager.add_ui(mid, path, name, name,
                              Gtk::UIManager::MENUITEM, false)
                end
        end
      end

      def add_menus_and_popups_from_xml
        log.debug { "add_menus_and_popups_from_xml" }
        [ "menus.xml", "popups.xml" ].each do |ui_file|
          @uimanager.add_ui(File.join(Alexandria::Config::DATA_DIR,
                                          "ui", ui_file))
        end
      end

      def setup_accel_group
        log.debug { "setup_accel_group" }
        @main_app.add_accel_group(@uimanager.accel_group)
      end

      def setup_menus
        log.debug { "setup_menus" }
        @main_app.menus = @uimanager.get_widget("/MainMenubar")
      end

      def setup_dialog_hooks
        log.debug { "setup_dialog_hooks" }
        Gtk::AboutDialog.set_url_hook do |about, link|
          log.debug { "set_url_hook" }
          open_web_browser(link)
        end
        Gtk::AboutDialog.set_email_hook do |about, link|
          log.debug { "set_email_hook" }
          open_email_client("mailto:" + link)
        end
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
        @main_app.signal_connect('window-state-event', &method(:on_window_state_event))
        @main_app.signal_connect('destroy', &method(:on_window_destroy))      
      end

      def setup_active_model
        log.debug { "setting up active model" }
        # The active model.

        list = [Gdk::Pixbuf,    # COVER_LIST
          Gdk::Pixbuf,    # COVER_ICON
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
          TrueClass,      #REDD
          TrueClass,      #OWN
          TrueClass,      #WANT
          String          # TAGS
        ]

        @model = Gtk::ListStore.new(*list)

        # Filter books according to the search toolbar widgets.
        @filtered_model = Gtk::TreeModelFilter.new(@model)
        @filtered_model.set_visible_func do |model, iter|
          #log.debug { "visible_func" }
          @filter_books_mode ||= 0
          filter = @filter_entry.text
          if filter.empty?
            true
          else
            data = case @filter_books_mode
                   when 0 then
                     (iter[Columns::TITLE] or "") +
                       (iter[Columns::AUTHORS] or "") +
                       (iter[Columns::ISBN] or "") +
                       (iter[Columns::PUBLISHER] or "") +
                       (iter[Columns::NOTES] or "") +
                       (iter[Columns::TAGS] or "")
                   when 2 then iter[Columns::TITLE]
                   when 3 then iter[Columns::AUTHORS]
                   when 4 then iter[Columns::ISBN]
                   when 5 then iter[Columns::PUBLISHER]
                   when 6 then iter[Columns::NOTES]
                   when 7 then iter[Columns::TAGS]
                   end
            data != nil and data.downcase.include?(filter.downcase)
          end
        end

        # Give filter entry the initial keyboard focus.
        @filter_entry.grab_focus
        log.debug { "done setting up active model" }
      end

      def on_library_button_press_event(widget, event)
        log.debug { "library_button_press_event" }
        # right click
        if event.event_type == Gdk::Event::BUTTON_PRESS and
          event.button == 3

          # This works, but the library loading is too slow!
          #                if path = widget.get_path_at_pos(event.x, event.y)
          #                     obj, path = widget.is_a?(Gtk::TreeView) \
          #                         ? [widget.selection, path.first] : [widget, path]

          #                     unless obj.path_is_selected?(path)
          #                         widget.unselect_all
          #                         obj.select_path(path)
          #                     end
          #                 else
          #                     widget.unselect_all
          #                 end
          #
          menu = determine_library_popup widget, event
          menu.popup(nil, nil, event.button, event.time)
        end
      end

      def determine_library_popup widget, event
        widget.get_path_at_pos(event.x, event.y) == nil \
          ? @nolibrary_popup \
          : selected_library.is_a?(SmartLibrary) \
          ? @smart_library_popup : @library_popup
      end

      def on_books_button_press_event(widget, event)
        log.debug { "books_button_press_event" }
        # right click
        if event.event_type == Gdk::Event::BUTTON_PRESS and
          event.button == 3

          widget.grab_focus

          if path = widget.get_path_at_pos(event.x.to_i, event.y.to_i)
            obj, path = widget.is_a?(Gtk::TreeView) ? [widget.selection, path.first] : [widget, path]

            unless obj.path_is_selected?(path)
              widget.unselect_all
              obj.select_path(path)
            end
          else
            widget.unselect_all
          end

          menu = (selected_books.empty?) ? @nobook_popup : @book_popup
          menu.popup(nil, nil, event.button, event.time)
        end
      end

      def on_books_selection_changed
        log.debug { "Initializing books_selection choice..." }
        library = selected_library
        books = selected_books
        @appbar.status = case books.length
                         when 0
                           case library.length
                           when 0
                             _("Library '%s' selected") % library.name

                           else
                             n_unrated = library.n_unrated
                             if n_unrated == library.length
                               n_("Library '%s' selected, %d unrated book",
                                  "Library '%s' selected, %d unrated books",
                                  library.length) % [ library.name,
                                    library.length ]
                             elsif n_unrated == 0
                               n_("Library '%s' selected, %d book",
                                  "Library '%s' selected, %d books",
                                  library.length) % [ library.name,
                                    library.length ]
                             else
                               n_("Library '%s' selected, %d book, " +
                                  "%d unrated",
                                  "Library '%s' selected, %d books, " +
                                  "%d unrated",
                                  library.length) % [ library.name,
                                    library.length,
                                    n_unrated ]
                             end
                           end
                         when 1
                           _("'%s' selected") % books.first.title
                         else
                           n_("%d book selected", "%d books selected",
                              books.length) % books.length
                         end
        unless @library_listview.has_focus?
          @actiongroup["Properties"].sensitive = \
            @actiongroup["OnlineInformation"].sensitive = \
            books.length == 1
          @actiongroup["SelectAll"].sensitive = \
            books.length < library.length
          @actiongroup["Delete"].sensitive = \
            @actiongroup["DeselectAll"].sensitive = \
            @actiongroup["Move"].sensitive =
            @actiongroup["SetRating"].sensitive = !books.empty?

          if library.is_a?(SmartLibrary)
            @actiongroup["Delete"].sensitive =
              @actiongroup["Move"].sensitive = false
          end

          # Sensitize providers URL
          if books.length == 1
            all_url = false
            BookProviders.each do |provider|
              has_url = books.first.isbn and provider.url(books.first) != nil
              @actiongroup[provider.action_name].sensitive = has_url
              all_url = true if has_url and !all_url
            end
            unless all_url
              @actiongroup["OnlineInformation"].sensitive = false
            end
          end
        end
      end

      def on_switch_page
        log.debug { "on_switch_page" }
        @actiongroup["ArrangeIcons"].sensitive = @notebook.page == 0
        on_books_selection_changed
      end

      def on_focus(widget, event_focus)
        log.debug { "on_focus" }
        if widget == @library_listview
          %w{OnlineInformation SelectAll DeselectAll}.each do |action|
            @actiongroup[action].sensitive = false
          end
          @actiongroup["Properties"].sensitive =
            selected_library.is_a?(SmartLibrary)
          @actiongroup["Delete"].sensitive =
            (@libraries.all_regular_libraries.length > 1 or
             selected_library.is_a?(SmartLibrary))
        else
          on_books_selection_changed
        end
      end

      def on_refresh
        log.debug { "on_refresh" }
        load_libraries
        refresh_libraries
        refresh_books
      end

      def on_close_sidepane
        log.debug { "on_close_sidepane" }
        @actiongroup["Sidepane"].active = false
      end

      def select_a_book book
        log.info { "select_a_book" }
        if selected_books.empty?
          iter = iter_from_book book
          path = iter.path
          log.info { "selecting path #{path}: #{path.inspect}" }
          @listview.selection.select_path(path)
          iter = iter_from_book book
          path = iter.path
          log.info { "selecting path #{path}: #{path.inspect}" }
          @iconview.select_path(path)
        end
      end

      def update(*ary)
        log.debug { "on_update #{ary}" }
        caller = ary.first
        if caller.is_a?(UndoManager)
          @actiongroup["Undo"].sensitive = caller.can_undo?
          @actiongroup["Redo"].sensitive = caller.can_redo?
        elsif caller.is_a?(Library)
          handle_update_caller_library ary
        else
          raise "unrecognized update event"
        end
      end

      def handle_update_caller_library ary
        library, kind, book = ary
        if library == selected_library
          @iconview.freeze
          case kind
          when Library::BOOK_ADDED
            append_book(book)
            select_a_book book
          when Library::BOOK_UPDATED
            iter = iter_from_ident(book.saved_ident)
            if iter
              fill_iter_with_book(iter, book)
            end
          when Library::BOOK_REMOVED
            @model.remove(iter_from_book(book))
          end
          @iconview.unfreeze
        elsif selected_library.is_a?(SmartLibrary)
          refresh_books
        end
      end

      #######
      #private
      #######

      def open_web_browser(url)
        unless (cmd = Preferences.instance.www_browser).nil?
          Thread.new { system(cmd % "\"" + url + "\"") }
        else
          ErrorDialog.new(@main_app,
                          _("Unable to launch the web browser"),
                          _("Check out that a web browser is " +
                            "configured as default (Desktop " +
                            "Preferences -> Advanced -> Preferred " +
                            "Applications) and try again."))
        end
      end

      def open_email_client(url)
        unless (cmd = Preferences.instance.email_client).nil?
          Thread.new { system(cmd % "\"" + url + "\"") }
        else
          ErrorDialog.new(@main_app,
                          _("Unable to launch the mail reader"),
                          _("Check out that a mail reader is " +
                            "configured as default (Desktop " +
                            "Preferences -> Advanced -> Preferred " +
                            "Applications) and try again."))
        end
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
        log.info { "Loading Libraries..." }
        @completion_models = CompletionModels.instance
        if @libraries
          detach_old_libraries
          @libraries.reload
        else
          @libraries = Libraries.instance
          @libraries.reload
          handle_ruined_libraries unless @libraries.ruined_books.empty?
        end
        @libraries.all_regular_libraries.each do |library|
          library.add_observer(self)
          @completion_models.add_source(library)
        end
      end

      def handle_ruined_books
        log.info { "Handling ruined books..." }
        message = _("These books do not conform to the ISBN-13 standard. We will attempt to replace them from the book providers. Otherwise, we will turn them into manual entries.\n" )
        @libraries.ruined_books.each {|bi| message += "\n#{bi[1] or bi[1].inspect}"}
        bad_isbn_warn = Gtk::MessageDialog.new(@main_app, Gtk::Dialog::MODAL, Gtk::MessageDialog::WARNING,  Gtk::MessageDialog::BUTTONS_CLOSE, message ).show
        bad_isbn_warn.signal_connect('response') { log.debug { "bad_isbn" }; bad_isbn_warn.destroy }
        books_to_add = []
        #This is the restoration thread. We can come up with strategies for restoring 'bad' books here.
        Thread.new do
          #Needs a progress indicator.
          @libraries.ruined_books.each {|book, isbn, library|
            begin
              books_to_add << [Alexandria::BookProviders.isbn_search(isbn.to_s), library].flatten
              log.debug { book.title }
            rescue
              books_to_add << [book, nil, library]
              log.debug { "#{book.title} didn't make it." }
            end
          }
          # Will crash here when it gets to it.
          books_to_add.each do |book, cover_uri, library|
            unless cover_uri.nil?
              library.save_cover(book, cover_uri)
            end
            library << book
            library.save(book)
          end
        end
        log.debug { books_to_add }
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
        iter[Columns::AUTHORS] = book.authors.join(', ')
        iter[Columns::ISBN] = book.isbn.to_s
        iter[Columns::PUBLISHER] = book.publisher
        iter[Columns::PUBLISH_DATE] = (book.publishing_year.to_s rescue "")
        iter[Columns::EDITION] = book.edition
        iter[Columns::NOTES] = (book.notes or "")
        rating = (book.rating or Book::DEFAULT_RATING)
        iter[Columns::RATING] = MAX_RATING_STARS - rating # ascending order is the default
        iter[Columns::OWN] = book.own?
        iter[Columns::REDD] = book.redd?
        iter[Columns::WANT] = book.want?
        if book.tags
          iter[Columns::TAGS] = book.tags.join(',')
        else
          iter[Columns::TAGS] = ""
        end

        icon = Icons.cover(selected_library, book)
        log.debug { "Setting icon #{icon} for book #{book.title}" }
        iter[Columns::COVER_LIST] = cache_scaled_icon(icon, 20, 25)

        if icon.height > ICON_HEIGHT
          new_width = icon.width / (icon.height / ICON_HEIGHT.to_f)
          new_height = [ICON_HEIGHT, icon.height].min
          icon = cache_scaled_icon(icon, new_width, new_height)
        end
        if rating == MAX_RATING_STARS
          icon = icon.tag(Icons::FAVORITE_TAG)
        end
        iter[Columns::COVER_ICON] = icon
        log.info { "Full iter: " + (0..15).collect {|num| iter[num].inspect }.join(", ") }
      end

      def append_book(book, tail=nil)
        log.debug { "append #{book.title}" }
        iter = tail ? @model.insert_after(tail) : @model.append
        if iter
          fill_iter_with_book(iter, book)
        else
          log.debug { "no iter for book #{book}" }
        end
        return iter
      end

      def append_library(library, autoselect=false)
        log.debug { "append_library #{library.name}" }
        model = @library_listview.model
        is_smart = library.is_a?(SmartLibrary)
        if is_smart
          if @library_separator_iter.nil?
            @library_separator_iter = append_library_separator
          end
          iter = model.append
        else
          iter = if @library_separator_iter.nil?
                   model.append
                 else
                   model.insert_before(@library_separator_iter)
                 end
        end

        iter[0] = is_smart \
          ? Icons::SMART_LIBRARY_SMALL : Icons::LIBRARY_SMALL
        iter[1] = library.name
        iter[2] = true      # editable?
        iter[3] = false     # separator?
        if autoselect
          @library_listview.set_cursor(iter.path,
                                       @library_listview.get_column(0),
                                       true)
          @actiongroup["Sidepane"].active = true
        end
        return iter
      end

      def append_library_separator
        log.debug { "append_library_separator" }
        iter = @library_listview.model.append
        iter[0] = nil
        iter[1] = nil
        iter[2] = false     # editable?
        iter[3] = true      # separator?
        return iter
      end

      BADGE_MARKUP = "<span weight=\"heavy\" foreground=\"white\">%d</span>"

      def refresh_books
        log.debug { "refresh_books" }
        # Clear the views.
        library = selected_library
        @model.clear
        @iconview.freeze
        @model.freeze_notify do
          tail = nil
          library.each { |book| tail = append_book(book, tail) }
        end
        @filtered_model.refilter
        @iconview.unfreeze
        @listview.columns_autosize

=begin
           # Append books - we do that in a separate thread.
           library = selected_library
           @appbar.progress_percentage = 0
           @appbar.children.first.visible = true   # show the progress bar
           @appbar.status = _("Loading '%s'...") % library.name
           exec_queue = ExecutionQueue.new

           on_progress = proc do |percent|
            @appbar.progress_percentage = percent
          end

           thread = Thread.start do
            total = library.length
            library.each_with_index do |book, n|
              append_book(book)
              # convert to percents
              coeff = total / 100.0
              percent = n / coeff
              fraction = percent / 100
              #log.debug { "#index #{n} percent #{percent} fraction #{fraction}"
              exec_queue.call(on_progress, fraction)
            end
          end

           while thread.alive?
             exec_queue.iterate
             Gtk.main_iteration_do(false)
           end

           @appbar.progress_percentage = 1
=end

        # Hide the progress bar.
        @appbar.children.first.visible = false

        # Refresh the status bar.
        on_books_selection_changed
      end

      def selected_library
        if iter = @library_listview.selection.selected
          @libraries.all_libraries.find { |x| x.name == iter[1] }
        else
          @libraries.all_libraries.first
        end
      end

      def select_library(library)
        log.debug { "select library #{library}" }
        iter = @library_listview.model.iter_first
        ok = true
        while ok do
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
        log.debug { "#{ident}" }
        iter = @model.iter_first
        ok = true
        while ok do
          if iter[Columns::IDENT] == ident
            return iter
          end
          ok = iter.next!
        end
        return nil
      end

      def iter_from_book(book)
        log.debug { "#{book}" }
        iter_from_ident(book.ident)
      end

      def selected_books
        a = []
        library = selected_library
        view = case @notebook.page
               when 0
                 @iconview.selected_each do |iconview, path|
                   path = @iconview_model.convert_path_to_child_path(path)
                   path = @filtered_model.convert_path_to_child_path(path)
                   iter = @model.get_iter(path)
                   a << book_from_iter(library, iter)
                 end

               when 1
                 @listview.selection.selected_each do |model, path,
                   iter|
                 path = @listview_model.convert_path_to_child_path(path)
                 path = @filtered_model.convert_path_to_child_path(path)
                 iter = @model.get_iter(path)
                 a << book_from_iter(library, iter)
                 end
               end
        selected = a.select { |x| x != nil }
        log.debug { "Selected books = #{selected}" }
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

        # Disable some actions if we selected a smart library.
        smart = library.is_a?(SmartLibrary)
        @actiongroup["AddBook"].sensitive = !smart
        @actiongroup["AddBookManual"].sensitive = !smart
        @actiongroup["Properties"].sensitive = smart
        @actiongroup["Delete"].sensitive =
          (@libraries.all_regular_libraries.length > 1 or smart)
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
        action = case @prefs.view_as
                 when 0
                   @actiongroup["AsIcons"]
                 when 1
                   @actiongroup["AsList"]
                 end
        action.activate
        library = nil
        unless @prefs.selected_library.nil?
          library = @libraries.all_libraries.find do |x|
            x.name == @prefs.selected_library
          end
        end
        select_a_library library
      end

      def select_a_library library
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
        cols_width = Hash.new
        @listview.columns.each do |c|
          cols_width[c.title] = [c.widget.size_request.first, c.width].max
        end
        @prefs.cols_width = '{' + cols_width.to_a.collect do |t, v|
            '"' + t + '": ' + v.to_s
        end.join(', ') + '}'
        log.debug { "cols_width: #{@prefs.cols_width} " }
      end

      def undoable_move(source, dest, books)
        log.debug { "undoable_move" }
        Library.move(source, dest, *books)
        UndoManager.instance.push { undoable_move(dest, source, books) }
      end

      def move_selected_books_to_library(library)
        books = selected_books.select do |book|
          !library.include?(book) or
          ConflictWhileCopyingDialog.new(@main_app,
                                         library,
                                         book).replace?
        end
        undoable_move(selected_library, library, books)
      end

      def setup_move_actions
        @actiongroup.actions.each do |action|
          next unless /^MoveIn/.match(action.name)
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
          [ "ui/MainMenubar/EditMenu/Move/",
              "ui/BookPopup/Move/" ].each do |path|
            @uimanager.add_ui(@move_mid, path, name, name,
                              Gtk::UIManager::MENUITEM, false)
              end
        end
      end


      # Gets the sort order of the current library, for use by export
      def library_sort_order
        # added by Cathal Mc Ginley, 23 Oct 2007
        log.info { "library_sort_order #{@notebook.page}: #{@iconview.model.inspect} #{@listview.model.inspect}" }
        current_view_model = case @notebook.page
                             when 0
                               @iconview.model
                             when 1
                               @listview.model
                             end
        sorted_on = current_view_model.sort_column_id
        if sorted_on
          sort_column = sorted_on[0]
          sort_order = sorted_on[1]

          column_ids_to_attributes = { 2 => :title,
            4 => :authors,
            5 => :isbn,
            6 => :publisher,
            7 => :publishing_year,
            8 =>:edition, #binding
            12 => :redd,
            13 => :own,
            14 => :want,
            9 => :rating}

          sort_attribute = column_ids_to_attributes[sort_column]
          ascending = (sort_order == Gtk::SORT_ASCENDING)
          LibrarySortOrder.new(sort_attribute, ascending)
        else
          LibrarySortOrder::Unsorted.new
        end
      end

      def undoable_delete(library, books=nil)
        # Deleting a library.
        if books.nil?
          library.delete_observer(self) if library.is_a?(Library)
          library.delete
          @libraries.remove_library(library)
          if @library_separator_iter != nil and
            @libraries.all_smart_libraries.empty?

            @library_listview.model.remove(@library_separator_iter)
            @library_separator_iter = nil
          end
          previous_selected_library = selected_library
          if previous_selected_library != library
            select_library(library)
          else
            previous_selected_library = nil
          end
          iter = @library_listview.selection.selected
          next_iter = @library_listview.selection.selected
          next_iter.next!
          @library_listview.model.remove(iter)
          @library_listview.selection.select_iter(next_iter)
          setup_move_actions
          select_library(previous_selected_library) \
            unless previous_selected_library.nil?
              # Deleting books.
            else
              books.each { |book| library.delete(book) }
            end
          UndoManager.instance.push { undoable_undelete(library, books) }
        end

        def undoable_undelete(library, books=nil)
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
          Columns::PUBLISHER, Columns::EDITION, Columns::RATING, Columns::REDD, Columns::OWN, Columns::WANT
        ]

        def setup_books_iconview_sorting
          sort_order = @prefs.reverse_icons ? Gtk::SORT_DESCENDING : Gtk::SORT_ASCENDING
          mode = ICONS_SORTS[@prefs.arrange_icons_mode]
          @iconview_model.set_sort_column_id(mode, sort_order)
          @filtered_model.refilter # force redraw
        end
      end
    end
  end
