# Copyright (C) 2004 Laurent Sansonetti
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
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

class Gtk::ActionGroup
    def [](x)
        get_action(x)
    end
end

class Alexandria::Library
    def action_name
        "MoveIn" + name.gsub(/\s/, '')
    end
end

module Alexandria
module UI
    class MainApp < GladeBase 
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize
            super("main_app.glade")
            @prefs = Preferences.instance
            load_libraries
            initialize_ui
            build_books_listview
            build_sidepane
            on_books_selection_changed
            restore_preferences
        end

        def on_books_button_press_event(widget, event)
            # double left click
            if event.event_type == Gdk::Event::BUTTON2_PRESS and
               event.button == 1 

                @actiongroup["Properties"].activate

            # right click
            elsif event.event_type == Gdk::Event::BUTTON_PRESS and
                  event.button == 3

                menu = (selected_books.empty?) ? @nobook_popup : @book_popup
                menu.popup(nil, nil, event.button, event.time) 
            end
        end

        def on_books_selection_changed
            library = selected_library
            books = selected_books
            @appbar.status = case books.length
                when 0
                    case library.length
                        when 0
                            _("Library '%s' selected") % library.name        
                                
                        else
                            n_("Library '%s' selected, %d book, %d unrated", 
                               "Library '%s' selected, %d books, %d unrated", 
                               library.length) % [ library.name, 
                                                   library.length, 
                                                   library.n_unrated ] 
                       end
                when 1
                    _("'%s' selected") % books.first.title
                else
                    n_("%d book selected", "%d books selected", books.length) \
                        % books.length
            end
            unless @treeview_sidepane.has_focus?
                @actiongroup["Properties"].sensitive = \
                    @actiongroup["OnlineInformation"].sensitive = \
                    books.length == 1
                @actiongroup["SelectAll"].sensitive = \
                    books.length < library.length
                @actiongroup["Delete"].sensitive = \
                    @actiongroup["DeselectAll"].sensitive = \
                    @actiongroup["Move"].sensitive = !books.empty?
            end
        end

        def on_switch_page
            @actiongroup["ArrangeIcons"].sensitive = @notebook.page == 0
            on_books_selection_changed
        end
        
        def on_focus(widget, event_focus)
            if widget == @treeview_sidepane
                %w{Properties OnlineInformation 
                   SelectAll DeselectAll}.each do |action| 
                    @actiongroup[action].sensitive = false
                end
                @actiongroup["Delete"].sensitive = true
            else
                on_books_selection_changed
            end
        end

        def on_refresh  
            # Clear the views.
            @listview.model.clear
            @iconlist.clear

            load_libraries            
            library = selected_library
            
            # Filter books according to the search toolbar widgets. 
            @filter_entry.text = filter_crit = @filter_entry.text.strip
            @filter_books_mode ||= 0
            library.delete_if do |book|
                !/#{filter_crit}/i.match case @filter_books_mode
                    when 0 then book.title
                    when 1 then book.authors.join
                    when 2 then book.isbn
                    when 3 then book.publisher
                    when 4 then (book.notes or "")
                end     
            end 

            # Append books in the list view.
            library.each { |book| append_book_in_list(book) }

            # Sort and reverse books according to the "Arrange Icons" menus.
            sort_funcs = [
                proc { |x, y| x.title <=> y.title },
                proc { |x, y| x.authors <=> y.authors },
                proc { |x, y| x.isbn <=> y.isbn },
                proc { |x, y| x.publisher <=> y.publisher },
                proc { |x, y| x.edition <=> y.edition },
                proc do |x, y| 
                    if x.rating.nil? or y.rating.nil?
                        0
                    else
                        x.rating <=> y.rating
                    end
                end 
            ]
            sort = sort_funcs[@prefs.arrange_icons_mode]
            library.sort! { |x, y| sort.call(x, y) } 
            library.reverse! if @prefs.reverse_icons
            
            # Append books in the icon view.
            library.each { |book| append_book_as_icon(book) }

            # Change the application's title.
            @main_app.title = library.name + " - " + TITLE
           
            # Show or hide list view columns according to the preferences. 
            cols_visibility = [
                @prefs.col_authors_visible,
                @prefs.col_isbn_visible,
                @prefs.col_publisher_visible,
                @prefs.col_edition_visible,
                @prefs.col_rating_visible
            ]
            cols = @listview.columns[1..-1] # skip "Title"
            cols.each_index do |i|
                cols[i].visible = cols_visibility[i]
            end

            # Disable the selected library in the move libraries actions.
            @libraries.each do |i_library|
                action = @actiongroup[i_library.action_name]
                action.sensitive = i_library != library if action
            end
            
            # Refresh the status bar.
            on_books_selection_changed
        end

        def on_close_sidepane
            @actiongroup["Sidepane"].active = false
        end

        #######
        private
        #######

        def open_web_browser(url)
            unless (cmd = Preferences.instance.www_browser).nil?
                system(cmd % "\"" + url + "\"")
            else 
                ErrorDialog.new(@main_app,
                                _("Unable to launch the web browser"),
                                _("Check out that a web browser is " +
                                  "configured as default (Applications -> " +
                                  "Desktop Preferences -> Advanced -> " +
                                  "Preferred Applications) and try again."))
            end
        end

        def load_libraries
            @libraries = Library.loadall
        end

        ICON_TITLE_MAXLEN = 20   # characters
        ICON_WIDTH = 48          # pixels
        def append_book_as_icon(book)
            title = book.title.sub(/^(.{#{ICON_TITLE_MAXLEN}}).*$/, '\1...')
            icon = Icons.cover(selected_library, book)
            new_height = icon.height / (icon.width / ICON_WIDTH.to_f)
            @iconlist.append_pixbuf(icon.scale(ICON_WIDTH, new_height), '', 
                                    title)
        end

        def append_book_in_list(book)
            iter = @listview.model.append 
            iter[0] = Icons.cover(selected_library, book).scale(20, 25)
            iter[1] = book.title
            iter[2] = book.authors.join(', ')
            iter[3] = book.isbn
            iter[4] = book.publisher
            iter[5] = book.edition
            rating = (book.rating or Book::DEFAULT_RATING)
            5.times do |i|
                iter[i + 6] = rating >= i.succ ? 
                    Icons::STAR_SET : Icons::STAR_UNSET
            end
            iter[11] = rating
            return iter
        end

        def append_library(library)
            iter = @treeview_sidepane.model.append
            iter[0] = Icons::LIBRARY_SMALL
            iter[1] = library.name
            iter[2] = true  #editable?
            return iter
        end

        def build_books_listview
            @listview.model = Gtk::ListStore.new(Gdk::Pixbuf, String, 
                                                 *([String] * 4 + 
                                                   [Gdk::Pixbuf] * 5 + 
                                                   [Integer]))

            # first column
            renderer = Gtk::CellRendererPixbuf.new
            column = Gtk::TreeViewColumn.new(_("Title"))
            column.pack_start(renderer, true)
            column.set_cell_data_func(renderer) do |column, cell, model, iter|
                cell.pixbuf = iter[0]
            end        
            renderer = Gtk::CellRendererText.new
            column.pack_start(renderer, true) 
            column.set_cell_data_func(renderer) do |column, cell, model, iter|
                cell.text = iter[1]
            end
            column.sort_column_id = 1
            column.resizable = true
            @listview.append_column(column)

            # other columns
            names = [ _("Authors"), _("ISBN"), _("Publisher"), _("Binding") ]
            names.each_index do |i|
                column = Gtk::TreeViewColumn.new(names[i], renderer, :text => i + 2)
                column.resizable = true
                column.sort_column_id = i + 2
                @listview.append_column(column)
            end

            # final column
            column = Gtk::TreeViewColumn.new(_("Rating"))
            5.times do |i|
                renderer = Gtk::CellRendererPixbuf.new
                column.pack_start(renderer, false)
                column.set_cell_data_func(renderer) do |column, cell, model, iter|
                    cell.pixbuf = iter[i + 6]
                end
            end
            column.sort_column_id = 11 
            column.resizable = false 
            @listview.append_column(column)

            @listview.selection.mode = Gtk::SELECTION_MULTIPLE
            @listview.selection.signal_connect('changed') { on_books_selection_changed }
        end

        def selected_library
            if iter = @treeview_sidepane.selection.selected
                @libraries.find { |x| x.name == iter[1] }
            else
                @libraries.first
            end
        end
   
        def select_library(library)
            iter = @treeview_sidepane.model.iter_first
            ok = true
            while ok do
                if iter[1] == library.name
                    @treeview_sidepane.selection.select_iter(iter)
                    break 
                end
                ok = iter.next!
            end
        end

        def selected_books
            a = []
            case @notebook.page
                when 0
                    @iconlist.selection.each do |i|
                        a << selected_library[i]    
                    end

                when 1
                    @listview.selection.selected_each do |model, path, iter| 
                        book = selected_library.find { |x| x.isbn == iter[3] }
                        if book
                            a << book
                        end
                    end
            end
            return a
        end   

        def build_sidepane
            @treeview_sidepane.model = Gtk::ListStore.new(Gdk::Pixbuf, 
                                                          String, TrueClass)
            @libraries.each { |library| append_library(library) } 
            renderer = Gtk::CellRendererPixbuf.new
            column = Gtk::TreeViewColumn.new(_("Library"))
            column.pack_start(renderer, false)
            column.set_cell_data_func(renderer) do |column, cell, model, iter|
                cell.pixbuf = iter[0]
            end        
            renderer = Gtk::CellRendererText.new
            column.pack_start(renderer, true) 
            column.set_cell_data_func(renderer) do |column, cell, model, iter|
                cell.text, cell.editable = iter[1], iter[2]
            end
            renderer.signal_connect('edited') do |cell, path_string, new_text|
                if cell.text != new_text
                    if match = /([^\w\s'"()?!:;.\-])/.match(new_text)
                        ErrorDialog.new(@main_app,
                                        _("Invalid library name '%s'") % new_text,
                                        _("The name provided contains the illegal " +
                                          "character '<i>%s</i>'.") % match[1])
                    elsif new_text.strip.empty?
                        ErrorDialog.new(@main_app, _("The library name can not be empty"))
                    elsif x = @libraries.find { |library| library.name == new_text.strip } \
                       and x.name != selected_library.name
                        ErrorDialog.new(@main_app, 
                                        _("The library can not be renamed"),
                                        _("There is already a library named " +
                                          "'#{new_text.strip}'.  Please choose a " +
                                          "different name."))
                    else
                        iter = @treeview_sidepane.model.get_iter(Gtk::TreePath.new(path_string))
                        iter[1] = selected_library.name = new_text.strip
                        setup_move_actions
                        on_refresh 
                    end
                end
            end
            @treeview_sidepane.append_column(column)
            @treeview_sidepane.selection.signal_connect('changed') { on_refresh } 
            @treeview_sidepane.selection.select_iter(@treeview_sidepane.model.iter_first) 
        end

        def restore_preferences
            if @prefs.maximized
                @main_app.maximize
            else
                @main_app.move(*@prefs.position) \
                    unless @prefs.position == [0, 0] 
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
            unless @prefs.selected_library.nil?
                library = @libraries.find do |x|
                    x.name == @prefs.selected_library
                end
                select_library(library) unless library.nil?
            end
        end

        def save_preferences
            @prefs.position = @main_app.position
            @prefs.size = @main_app.allocation.to_a[2..3]
            @prefs.maximized = @maximized
            @prefs.sidepane_position = @paned.position
            @prefs.sidepane_visible = @actiongroup["Sidepane"].active?
            @prefs.toolbar_visible = @actiongroup["Toolbar"].active? 
            @prefs.statusbar_visible = @actiongroup["Statusbar"].active?
            @prefs.view_as = @notebook.page
            @prefs.selected_library = selected_library.name
        end 
       
        def setup_move_actions
            @actiongroup.actions.each do |action|
                next unless /^MoveIn/.match(action.name)
                @actiongroup.remove_action(action)
            end
            actions = @libraries.map do |library|
                [library.action_name, nil,
                 _("In '_%s'") % library.name, nil, nil,
                 proc { Library.move(selected_library, 
                                     library, *selected_books)
                        on_refresh }]
            end
            @actiongroup.add_actions(actions)
            if @move_mid
                @uimanager.remove_ui(@move_mid)
            end
            @move_mid = @uimanager.new_merge_id 
            @libraries.each do |library|
                name = library.action_name
                [ "ui/MainMenubar/EditMenu/Move/",
                  "ui/BookPopup/Move/" ].each do |path|
                    @uimanager.add_ui(@move_mid, path, name, name,
                                      Gtk::UIManager::MENUITEM, false)
                end
            end
        end
        
        def initialize_ui
            @main_app.icon = Icons::ALEXANDRIA_SMALL

            on_new = proc do
                i = 1
                while true do
                    name = _("Untitled %d") % i
                    break unless @libraries.find { |x| x.name == name }
                    i += 1
                end
                library = Library.load(name)
                @libraries << library
                iter = append_library(library)
                @actiongroup["Sidepane"].active = true
                @treeview_sidepane.set_cursor(iter.path, 
                                              @treeview_sidepane.get_column(0), 
                                              true)
                setup_move_actions
            end
    
            on_add_book = proc do
                NewBookDialog.new(@main_app, 
                                  @libraries, 
                                  selected_library) do |books, library|
                    if selected_library == library
                        on_refresh
                    else
                        select_library(library)
                    end
                end
            end
     
            on_add_book_manual = proc do
                NewBookDialogManual.new(@main_app, selected_library) do |book|
                    on_refresh
                end
            end
            
            on_import = proc {}
            on_export = proc { ExportDialog.new(@main_app, selected_library) }
        
            on_properties = proc do
                books = selected_books
                if books.length == 1
                    BookPropertiesDialog.new(@main_app, selected_library, 
                                             books.first) { on_refresh }
                end
            end

            on_quit = proc do
                save_preferences
                Gtk.main_quit
            end
   
            on_select_all = proc do
                case @notebook.page
                    when 0
                        @iconlist.num_icons.times do |i|
                            @iconlist.select_icon(i)
                        end
                    when 1
                        @listview.selection.select_all
                end
            end
            
            on_deselect_all = proc do
                case @notebook.page
                    when 0
                        @iconlist.unselect_all
                    when 1
                        @listview.selection.unselect_all
                end
            end
            
            on_delete = proc do
                library = selected_library
                confirm = lambda do |message|
                    dialog = AlertDialog.new(@main_app, message,
                                             Gtk::Stock::DIALOG_QUESTION,
                                             [[Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                              [Gtk::Stock::DELETE, Gtk::Dialog::RESPONSE_OK]])
                    dialog.default_response = Gtk::Dialog::RESPONSE_CANCEL
                    dialog.show_all
                    res = dialog.run == Gtk::Dialog::RESPONSE_OK
                    dialog.destroy
                    res
                end
                if @treeview_sidepane.focus?
                    message = case library.length
                        when 0
                            _("Are you sure you want to permanently delete '%s'?") % library.name
                        when 1
                            _("Are you sure you want to permanently delete '%s' " +
                              "which has one book?") % library.name
                        else
                            n_("Are you sure you want to permanently delete '%s' " +
                               "which has %d book?", 
                               "Are you sure you want to permanently delete '%s' " +
                               "which has %d books?", library.size) % [ library.name, library.size ]
                    end
                    if confirm.call(message)
                        library.delete
                        @libraries.delete_if { |lib| lib.name == library.name }
                        iter = @treeview_sidepane.selection.selected
                        next_iter = @treeview_sidepane.selection.selected
                        next_iter.next!
                        @treeview_sidepane.model.remove(iter)
                        @treeview_sidepane.selection.select_iter(next_iter)
                        setup_move_actions
                    end
                else
                    selected_books.each do |book|
                        if confirm.call(_("Are you sure you want to permanently " +
                                          "delete '%s' from '%s'?") % [ book.title, library.name ])
                            library.delete(book)
                            on_refresh
                        end
                    end
                end
            end
     
            on_clear_search_results = proc do
                @filter_entry.text = ""
                on_refresh
            end
    
            on_search = proc { @filter_entry.grab_focus }
            on_preferences = proc { PreferencesDialog.new(@main_app) { on_refresh } }
            on_submit_bug_report = proc { open_web_browser(BUGREPORT_URL) }
            on_about = proc { AboutDialog.new(@main_app).show }

            standard_actions = [
                ["LibraryMenu", nil, _("_Library")],
                ["New", Gtk::Stock::NEW, _("_New"), "<control>L", nil, on_new],
                ["AddBook", Gtk::Stock::ADD, _("_Add Book..."), "<control>N", nil, on_add_book],
                ["AddBookManual", nil, _("Add Book _Manually..."), nil, nil, on_add_book_manual],
                ["Import", nil, _("_Import..."), "<control>I", nil, on_import],
                ["Export", nil, _("_Export..."), "<control><shift>E", nil, on_export],
                ["Properties", Gtk::Stock::PROPERTIES, _("_Properties"), nil, nil, on_properties],
                ["Quit", Gtk::Stock::QUIT, _("_Quit"), "<control>Q", nil, on_quit],
                ["EditMenu", nil, _("_Edit")],
                ["SelectAll", nil, _("_Select All"), "<control>A", nil, on_select_all],
                ["DeselectAll", nil, _("Dese_lect All"), "<control><shift>A", nil, on_deselect_all],
                ["Move", nil, _("_Move")],
                ["Delete", Gtk::Stock::DELETE, _("_Delete"), "Delete", nil, on_delete],
                ["Search", Gtk::Stock::FIND, _("_Search"), "<control>F", nil, on_search],
                ["ClearSearchResult", Gtk::Stock::CLEAR, _("_Clear Results"), "<control><alt>B", nil, 
                 on_clear_search_results],
                ["Preferences", Gtk::Stock::PREFERENCES, _("_Preferences"), nil, nil, on_preferences],
                ["ViewMenu", nil, _("_View")],
                ["Refresh", Gtk::Stock::REFRESH, _("_Refresh"), "<control>F", nil, proc { on_refresh }],
                ["ArrangeIcons", nil, _("Arran_ge Icons")],
                ["OnlineInformation", nil, _("Display Online _Information")],
                ["HelpMenu", nil, _("_Help")],
                ["SubmitBugReport", Gnome::Stock::MAIL_NEW, _("Submit _Bug Report"), nil, nil,
                 on_submit_bug_report],
                ["About", Gnome::Stock::ABOUT, _("_About"), nil, nil, on_about]
            ]

            on_view_sidepane = proc { |ag, a| @paned.child1.visible = a.active? }
            on_view_toolbar = proc { |ag, a| @toolbar.parent.visible = a.active? }
            on_view_statusbar = proc { |ag, a| @appbar.visible = a.active? }
            
            on_reverse_order = proc do |actiongroup, action|
                Preferences.instance.reverse_icons = action.active? 
                on_refresh
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
                ["At" + provider.name, Gtk::Stock::JUMP_TO, 
                 _("At _%s") % provider.fullname, nil, nil, 
                 proc { open_web_browser(provider.url(selected_books.first)) }]
            end
            
            @actiongroup = Gtk::ActionGroup.new("actions")
            @actiongroup.add_actions(standard_actions)
            @actiongroup.add_actions(providers_actions)
            @actiongroup.add_toggle_actions(toggle_actions)
            @actiongroup.add_radio_actions(view_as_actions) do |action, current|
                @notebook.page = current.current_value
                @toolbar_view_as.signal_handler_block(@toolbar_view_as_signal_hid) do
                    @toolbar_view_as.active = current.current_value 
                end
            end
            @actiongroup.add_radio_actions(arrange_icons_actions) do |action, current|
                @prefs.arrange_icons_mode = current.current_value 
                on_refresh
            end
            
            @uimanager = Gtk::UIManager.new
            @uimanager.insert_action_group(@actiongroup, 0)
            @main_app.add_accel_group(@uimanager.accel_group)
            
            [ "menus.xml", "popups.xml" ].each do |ui_file|
                @uimanager.add_ui(File.join(Alexandria::Config::DATA_DIR, 
                                           "ui", ui_file))
            end

            mid = @uimanager.new_merge_id 
            BookProviders.each do |provider|
                name = "At" + provider.name    
                [ "ui/MainMenubar/ViewMenu/OnlineInformation/",
                  "ui/BookPopup/OnlineInformation/",
                  "ui/NoBookPopup/OnlineInformation/" ].each do |path|
                    @uimanager.add_ui(mid, path, name, name, 
                                     Gtk::UIManager::MENUITEM, false)
                end
            end

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
            
            @toolbar = @uimanager.get_widget("/MainToolbar")
            @toolbar.insert(-1, Gtk::SeparatorToolItem.new)
            
            cb = Gtk::ComboBox.new
            [ _("Title contains"), _("Authors contain"), 
              _("ISBN contains"), _("Publisher contains"), 
              _("Notes contain") ].each do |item|
                cb.append_text(item)
            end
            cb.active = 0
            cb.signal_connect('changed') do |cb|
                @filter_books_mode = cb.active 
                on_refresh unless @filter_entry.text.strip.empty?
            end
            toolitem = Gtk::ToolItem.new
            toolitem.border_width = 5
            toolitem << cb
            @toolbar.insert(-1, toolitem)
            
            @filter_entry = Gtk::Entry.new
            @filter_entry.signal_connect('activate') { on_refresh }
            toolitem = Gtk::ToolItem.new
            toolitem.expand = true
            toolitem.border_width = 5
            toolitem << @filter_entry
            @toolbar.insert(-1, toolitem)
            
            @toolbar.insert(-1, Gtk::SeparatorToolItem.new)
           
            @toolbar_view_as = Gtk::ComboBox.new
            @toolbar_view_as.append_text(_("View as Icons"))
            @toolbar_view_as.append_text(_("View as List"))
            @toolbar_view_as.active = 0
            @toolbar_view_as_signal_hid = \
                @toolbar_view_as.signal_connect('changed') do |cb| 
                    action = case cb.active
                        when 0
                            @actiongroup['AsIcons']
                        when 1
                            @actiongroup['AsList']
                    end
                    action.active = true
                end
            toolitem = Gtk::ToolItem.new
            toolitem.border_width = 5 
            toolitem << @toolbar_view_as
            @toolbar.insert(-1, toolitem)
            
            @toolbar.show_all
            
            @main_app.toolbar = @toolbar
            @main_app.menus = @uimanager.get_widget("/MainMenubar")
            @book_popup = @uimanager.get_widget("/BookPopup") 
            @nobook_popup = @uimanager.get_widget("/NoBookPopup") 
            
            @main_app.signal_connect('window-state-event') do |w, e|
                if e.is_a?(Gdk::EventWindowState)
                    @maximized = \
                        e.new_window_state == Gdk::EventWindowState::MAXIMIZED 
                end
            end
        
            @main_app.signal_connect('destroy') do 
                @actiongroup["Quit"].activate
            end
            
            setup_move_actions
        end
    end
end
end
