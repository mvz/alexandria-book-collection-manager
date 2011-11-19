# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2008 Joseph Method
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
    module Callbacks

      include Logging

      def on_new widget, event
        name = Library.generate_new_name(@libraries.all_libraries)
        library = Library.load(name)
        @libraries.add_library(library)
        append_library(library, true)
        setup_move_actions
        library.add_observer(self)
      end

      def on_new_smart widget, event
        NewSmartLibraryDialog.new(@main_app) do |smart_library|
          smart_library.refilter
          @libraries.add_library(smart_library)
          append_library(smart_library, true)
          smart_library.save
        end
      end

      def on_add_book widget, event
        log.info { "on_add_book" }
        NewBookDialog.new(@main_app, selected_library) do |books, library, is_new|
          if is_new
            append_library(library, true)
            setup_move_actions
          elsif selected_library != library
            select_library(library)
          end
        end
      end

      def on_add_book_manual widget, event
        library = selected_library
        NewBookDialogManual.new(@main_app, library) { |book|
          refresh_books
        }
      end

      def on_import widget, event
        ImportDialog.new(@main_app) do |library, bad_isbns, failed_isbns|
          unless bad_isbns.empty?
            message = _("The following lines are not valid ISBNs and were not imported:")
            bad_isbn_warn = BadIsbnsDialog.new(@main_app, message, bad_isbns)
            bad_isbn_warn.signal_connect('response') { log.debug { "bad_isbn" }; bad_isbn_warn.destroy }
          end
          unless failed_isbns.nil? || failed_isbns.empty?
            message= _("Books could not be found for the following ISBNs:")
            failed_lookup = BadIsbnsDialog.new(@main_app, message, failed_isbns)
            failed_lookup.signal_connect('response') { log.debug { "failed lookup of #{failed_isbns.size} ISBNs" }; failed_lookup.destroy }
          end
          @libraries.add_library(library)
          append_library(library, true)
          setup_move_actions
        end
      end

      def on_window_state_event window, event
        log.debug { "window-state-event" }
        if event.is_a?(Gdk::EventWindowState)
          @maximized = event.new_window_state == Gdk::EventWindowState::MAXIMIZED
        end
        log.debug { "end window-state-event" }
      end

      def on_toolbar_view_as_changed cb
        log.debug { "changed" }
        action = case cb.active
                 when 0
                   @actiongroup['AsIcons']
                 when 1
                   @actiongroup['AsList']
                 end
        action.active = true
      end

      def on_window_destroy window
        log.debug { "destroy" }
        @actiongroup["Quit"].activate
      end

      def on_toolbar_filter_entry_changed(entry)
        log.debug { "changed" }
        @filter_entry.text.strip!
        @iconview.freeze
        @filtered_model.refilter
        @iconview.unfreeze
      end

      def on_criterion_combobox_changed(cb)
        log.debug { "changed" }
        @filter_books_mode = cb.active
        @filter_entry.text.strip!
        @iconview.freeze
        @filtered_model.refilter
        @iconview.unfreeze
      end

      def on_export widget, event
        begin
          ExportDialog.new(@main_app, selected_library, library_sort_order)
        rescue Exception => ex
          log.error { "problem with immediate export #{ex} try again" }

          ErrorDialog.new(@main_app, _("Export failed"),
                              _("Try letting this library load " + 
                                "completely before exporting."))
        end
      end

      def on_acquire widget, event
        AcquireDialog.new(@main_app,
                          selected_library) do |books, library, is_new|
          if is_new
            append_library(library, true)
            setup_move_actions
          elsif selected_library != library
            select_library(library)
          end
                          end
      end

      def on_properties widget, event
        if @library_listview.focus? or selected_books.empty?
          library = selected_library
          if library.is_a?(SmartLibrary)
            SmartLibraryPropertiesDialog.new(@main_app, library) do
              library.refilter
              refresh_books
            end
          end
        else
          books = selected_books
          if books.length == 1
            book = books.first
            BookPropertiesDialog.new(@main_app,
                                     selected_library,
                                     book) #{ |modified_book| }
          end
        end
      end

      def on_quit widget, event
        save_preferences
        Gtk.main_quit
        #@libraries.really_save_all_books
        @libraries.really_delete_deleted_libraries
        @libraries.all_regular_libraries.each do |library|
          library.really_delete_deleted_books
        end
      end

      def on_undo widget, event
        UndoManager.instance.undo!
      end

      def on_redo widget, event
        UndoManager.instance.redo!
      end

      def on_select_all widget, event
        log.debug { "on_select_all" }
        case @notebook.page
        when 0
          @iconview.select_all
        when 1
          @listview.selection.select_all
        end
      end

      def on_deselect_all widget, event
        log.debug { "on_deselect_all" }
        case @notebook.page
        when 0
          @iconview.unselect_all
        when 1
          @listview.selection.unselect_all
        end
      end

      def on_set_rating
        (0..MAX_RATING_STARS).map do |rating|
          proc do
            books = selected_books
            library = selected_library
            books.each do |book|
              log.debug { "set #{book.title} rating to #{rating}" }
              book.rating = rating
              library.save(book)
            end
          end
        end
      end

      def on_rename widget, event
        iter = @library_listview.selection.selected
        @library_listview.set_cursor(iter.path,
                                     @library_listview.get_column(0),
                                     true)
      end

      def on_delete widget, event
        library = selected_library

        if selected_books.empty?
          books = nil
        else
          books = selected_books
        end
        #books = @library_listview.focus? ? nil : selected_books
        is_smart = library.is_a?(SmartLibrary)
        last_library = (@libraries.all_regular_libraries.length == 1)
        if (books.nil? && !is_smart && last_library)
          log.warn { "Attempted to delete last library, fix GUI" }
          return
        end
        if library.empty? or ReallyDeleteDialog.new(@main_app,
                                                    library,
                                                    books).ok?
          undoable_delete(library, books)
        end
      end

      def on_clear_search_results widget, event
        @filter_entry.text = ""
        @iconview.freeze
        @filtered_model.refilter
        @iconview.unfreeze
      end

      def on_search widget, event
        @filter_entry.grab_focus
      end

      def on_preferences widget, event
        PreferencesDialog.new(@main_app) do
          @listview_manager.setup_listview_columns_visibility
        end
      end

      def on_submit_bug_report widget, event
        open_web_browser(BUGREPORT_URL)
      end

      def on_help widget, event
        Alexandria::UI::display_help(@main_app)
      end

      def on_about widget, event
        ad = AboutDialog.new(@main_app)
        ad.signal_connect('response'){ log.debug { "destroy about"; ad.destroy } }
        ad.show
      end

      def connect_signals
        standard_actions = [
          ["LibraryMenu", nil, _("_Library")],
          ["New", Gtk::Stock::NEW, _("_New Library"), "<control>L", _("Create a new library"), method(:on_new)],
          ["NewSmart", nil, _("New _Smart Library..."), "<control><shift>L", _("Create a new smart library"), method(:on_new_smart)],
          ["AddBook", Gtk::Stock::ADD, _("_Add Book..."), "<control>N", _("Add a new book from the Internet"), method(:on_add_book)],
          ["AddBookManual", nil, _("Add Book _Manually..."), "<control><shift>N", _("Add a new book manually"), method(:on_add_book_manual)],
          ["Import", nil, _("_Import..."), "<control>I", _("Import a library"), method(:on_import)],
          ["Export", nil, _("_Export..."), "<control><shift>E", _("Export the selected library"), method(:on_export)],
          ["Acquire", nil, _("A_cquire from Scanner..."), "<control><shift>S", _("Acquire books from a scanner"), method(:on_acquire)],
          ["Properties", Gtk::Stock::PROPERTIES, _("_Properties"), nil, _("Edit the properties of the selected book"), method(:on_properties)],
          ["Quit", Gtk::Stock::QUIT, _("_Quit"), "<control>Q", _("Quit the program"), method(:on_quit)],
          ["EditMenu", nil, _("_Edit")],
          ["Undo", Gtk::Stock::UNDO, _("_Undo"), "<control>Z", _("Undo the last action"), method(:on_undo)],
          ["Redo", Gtk::Stock::REDO, _("_Redo"), "<control><shift>Z", _("Redo the undone action"), method(:on_redo)],
          ["SelectAll", nil, _("_Select All"), "<control>A", _("Select all visible books"), method(:on_select_all)],
          ["DeselectAll", nil, _("Dese_lect All"), "<control><shift>A", _("Deselect everything"), method(:on_deselect_all)],
          ["SetRating", nil, _("My _Rating")],
          ["SetRating0", nil, _("None"), nil, nil, proc { on_set_rating[0].call }],
          ["SetRating1", nil, _("One Star"), nil, nil, proc { on_set_rating[1].call } ],
          ["SetRating2", nil, _("Two Stars"), nil, nil, proc { on_set_rating[2].call }],
          ["SetRating3", nil, _("Three Stars"), nil, nil, proc { on_set_rating[3].call }],
          ["SetRating4", nil, _("Four Stars"), nil, nil, proc { on_set_rating[4].call }],
          ["SetRating5", nil, _("Five Stars"), nil, nil, proc { on_set_rating[5].call } ],
          ["Move", nil, _("_Move")],
          ["Rename", nil, _("_Rename"), nil, nil, method(:on_rename)],
          ["Delete", Gtk::Stock::DELETE, _("_Delete"), "Delete", _("Delete the selected books or library"), method(:on_delete)],
          ["Search", Gtk::Stock::FIND, _("_Search"), "<control>F", _("Filter books"), method(:on_search)],
            ["ClearSearchResult", Gtk::Stock::CLEAR, _("_Clear Results"), "<control><alt>B", _("Clear the search results"), method(:on_clear_search_results)],
            ["Preferences", Gtk::Stock::PREFERENCES, _("_Preferences"), "<control>O", _("Change Alexandria's settings"), method(:on_preferences)],
          ["ViewMenu", nil, _("_View")],
            ["ArrangeIcons", nil, _("Arran_ge Icons")],
            ["OnlineInformation", nil, _("Display Online _Information")],

          ["HelpMenu", nil, _("_Help")],
            ["SubmitBugReport", Gtk::Stock::EDIT, _("Submit _Bug Report"), nil, _("Submit a bug report to the developers"), method(:on_submit_bug_report)],
            ["Help", Gtk::Stock::HELP, _("Contents"), "F1", _("View Alexandria's manual"), method(:on_help)],
            ["About", Gtk::Stock::ABOUT, _("_About"), nil, _("Show information about Alexandria"), method(:on_about)],
        ]

        on_view_sidepane = proc do |actiongroup, action|
          log.debug { "on_view_sidepane" }
          @paned.child1.visible = action.active?
        end

        on_view_toolbar = proc do |actiongroup, action|
          log.debug { "on_view_toolbar" }
          @toolbar.parent.visible = action.active?
        end

        on_view_statusbar = proc do |actiongroup, action|
          log.debug { "on_view_statusbar" }
          @appbar.visible = action.active?
        end

        on_reverse_order = proc do |actiongroup, action|
          log.debug { "on_reverse_order" }
          Preferences.instance.reverse_icons = action.active?
          Preferences.instance.save!
          setup_books_iconview_sorting
        end

        toggle_actions = [
          ["Sidepane", nil, _("Side _Pane"), "F9", nil,
            on_view_sidepane, true],
          ["Toolbar", nil, _("_Toolbar"), nil, nil,
            on_view_toolbar, true],
          ["Statusbar", nil, _("_Statusbar"), nil, nil,
            on_view_statusbar, true],
          ["ReversedOrder", nil, _("Re_versed Order"), nil, nil,
            on_reverse_order],
        ]

        view_as_actions = [
          ["AsIcons", nil, _("View as _Icons"), nil, nil, 0],
          ["AsList", nil, _("View as _List"), nil, nil, 1]
        ]

        arrange_icons_actions = [
          ["ByTitle", nil, _("By _Title"), nil, nil, 0],
          ["ByAuthors", nil, _("By _Authors"), nil, nil, 1],
          ["ByISBN", nil, _("By _ISBN"), nil, nil, 2],
          ["ByPublisher", nil, _("By _Publisher"), nil, nil, 3],
          ["ByEdition", nil, _("By _Binding"), nil, nil, 4],
          ["ByRating", nil, _("By _Rating"), nil, nil, 5]
        ]
        providers_actions = BookProviders.map do |provider|
          [provider.action_name, Gtk::Stock::JUMP_TO,
            _("At _%s") % provider.fullname, nil, nil,
            proc { open_web_browser(provider.url(selected_books.first)) }]
        end

        log.debug { "Adding actions to @actiongroup" }

        @actiongroup = Gtk::ActionGroup.new("actions")
        @actiongroup.add_actions(standard_actions)
        @actiongroup.add_actions(providers_actions)
        @actiongroup.add_toggle_actions(toggle_actions)
        @actiongroup.add_radio_actions(view_as_actions) do |action, current|
          @notebook.page = current.current_value
          hid = @toolbar_view_as_signal_hid
          @toolbar_view_as.signal_handler_block(hid) do
            @toolbar_view_as.active = current.current_value
          end
        end
        @actiongroup.add_radio_actions(arrange_icons_actions) do |action, current|
          @prefs.arrange_icons_mode = current.current_value
          setup_books_iconview_sorting
        end
      end
    end
  end
end
