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

module Alexandria
module UI
    class MainApp < GladeBase 
        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        def initialize
            super("main_app.glade")
            @main_app.icon = Icons::ALEXANDRIA_SMALL
            @prefs = Preferences.instance
            load_libraries
            build_books_listview
            build_sidepane
            on_books_selection_changed
            restore_preferences

            @main_app.signal_connect('window-state-event') do |w, e|
                if e.is_a?(Gdk::EventWindowState)
                    @maximized = e.new_window_state == Gdk::EventWindowState::MAXIMIZED 
                end
            end
            
            providers_menu = Gtk::Menu.new
            BookProviders.each do |provider|
                item = Gtk::MenuItem.new("_" + provider.fullname, true) 
                item.signal_connect('activate') do
                    open_web_browser(provider.url(selected_books.first))
                end 
                providers_menu.append(item)
            end
            providers_menu.show_all
            @popup_online_info.submenu = providers_menu
        end

        def on_books_button_press_event(widget, event)
            # double left click
            if event.event_type == Gdk::Event::BUTTON2_PRESS and
               event.button == 1 

                on_book_properties

            # right click
            elsif event.event_type == Gdk::Event::BUTTON_PRESS and
                  event.button == 3

                books = selected_books
                if books.empty?
                    popup = @nobook_popup
                    va_icons, va_list = popup.children[-2..-1]
                    arr_icons = popup.children[-4]
                else
                    popup = @book_popup
                    va_icons, va_list = popup.children[-4..-3]
                    arr_icons = popup.children[-6]
                end

                case @notebook.page
                    when 0
                        va_icons.active = true
                        arr_icons.sensitive = true
                        arr_icons.submenu.children[@prefs.arrange_icons_mode].active = true
                        arr_icons.submenu.children.last.active = @prefs.reverse_icons

                    when 1
                        va_list.active = true
                        arr_icons.sensitive = false
                end
                
                popup.popup(nil, nil, event.button, event.time) 
            end
        end

        def on_books_selection_changed
            books = selected_books
            @appbar.status = case books.length
                when 0
                    ""
                when 1
                    _("'%s' selected") % books.first.title
                else
                    n_("%d book selected", "%d books selected", books.length) \
                        % books.length
            end
            @popup_properties.sensitive = @popup_online_info.sensitive = @menu_properties.sensitive = books.length == 1
            @menu_delete.sensitive = !books.empty? 
        end

        def on_focus(widget, event_focus)
            if widget == @treeview_sidepane
                @menu_properties.sensitive = false
                @menu_delete.sensitive = true
            end
        end

        def on_import
            # TODO
        end

        def on_export
            ExportDialog.new(@main_app, selected_library)
        end
        
        def on_book_properties
            books = selected_books
            if books.length == 1
                InfoBookDialog.new(@main_app, selected_library, books.first) do
                    on_refresh
                end
            end
        end

        def on_new_book
            NewBookDialog.new(@main_app, @libraries, selected_library) do |books, library|
                if selected_library == library
                    on_refresh
                else
                    select_library(library)
                end
            end
        end
     
        def on_new_library
            i = 1
            while true do
                name = _("Untitled %d") % i
                break unless @libraries.find { |x| x.name == name }
                i += 1
            end
            library = Library.load(name)
            @libraries << library
            iter = append_library(library)
            @paned.child1.visible = @menu_view_sidepane.active = true
            @treeview_sidepane.set_cursor(iter.path, @treeview_sidepane.get_column(0), true)
        end
    
        def on_quit
            save_preferences
            Gtk.main_quit
        end
   
        def on_delete
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
                        _("Are you sure you want to permanently delete '%s' which has one book?") % library.name
                    else
                        n_("Are you sure you want to permanently delete '%s' which has %d book?", "Are you sure you want to permanently delete '%s' which has %d books?", library.size) % [ library.name, library.size ]
                end
                if confirm.call(message)
                    library.delete
                    @libraries.delete_if { |lib| lib.name == library.name }
                    iter = @treeview_sidepane.selection.selected
                    next_iter = @treeview_sidepane.selection.selected
                    next_iter.next!
                    @treeview_sidepane.model.remove(iter)
                    @treeview_sidepane.selection.select_iter(next_iter)
                end
            else
                selected_books.each do |book|
                    if confirm.call(_("Are you sure you want to permanently delete '%s' from '%s'?") % [ book.title, library.name ])
                        library.delete(book)
                        on_refresh
                    end
                end
            end
        end

        def on_select_all
            case @notebook.page
                when 0
                    @iconlist.num_icons.times { |i| @iconlist.select_icon(i) }
                when 1
                    @listview.selection.select_all
            end
        end

        def on_deselect_all
            case @notebook.page
                when 0
                    @iconlist.unselect_all
                when 1
                    @listview.selection.unselect_all
            end
        end

        def on_search
            @filter_entry.grab_focus
        end
 
        def on_clear_search_results
            @filter_entry.text = ""
            on_refresh
        end

        def on_preferences
            PreferencesDialog.new(@main_app) { on_refresh } 
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
        end

        def on_close_sidepane
            @paned.child1.visible = false
            @menu_view_sidepane.active = false
        end

        def on_view_sidepane(item)
            @paned.child1.visible = item.active?
        end    

        def on_view_toolbar(item)
            @bonobodock_toolbar.visible = item.active?        
        end
    
        def on_view_statusbar(item)
            @appbar.visible = item.active?
        end
 
        def on_view_as_icons(widget)
            @notebook.page = 0
            @menu_arrange_icons.sensitive = true
            if widget.name.include?('popup_view_as_icons') or widget == @menu_view_as_icons
                @toolbar_view_as.menu.active = @toolbar_view_as.history = 0
            end
            if widget.name.include?('popup_view_as_icons') or widget == @toolbar_view_as_icons
                @menu_view_as_icons.active = true
            end
        end

        def on_view_as_list(widget)
            @notebook.page = 1
            @menu_arrange_icons.sensitive = false 
            if widget.name.include?('popup_view_as_list') or widget == @menu_view_as_list
                @toolbar_view_as.menu.active = @toolbar_view_as.history = 1
            end
            if widget.name.include?('popup_view_as_list') or widget == @toolbar_view_as_list
                @menu_view_as_list.active = true
            end
        end

        def on_filter_by_title
            update_filter_books_mode(0)
        end

        def on_filter_by_authors
            update_filter_books_mode(1)
        end

        def on_filter_by_isbn
            update_filter_books_mode(2)
        end
        
        def on_filter_by_publisher
            update_filter_books_mode(3)
        end
        
        def on_filter_by_notes
            update_filter_books_mode(4)
        end
        
        def on_menu_arrange_icons_selected
            items = [ @menu_icons_by_title, @menu_icons_by_authors, @menu_icons_by_isbn,
                      @menu_icons_by_publisher, @menu_icons_by_edition, @menu_icons_by_rating ]
            items[Preferences.instance.arrange_icons_mode].active = true
            @menu_icons_reversed_order.active = Preferences.instance.reverse_icons
        end

        def on_arrange_icons_by_title
            update_arrange_icons_mode(0)
        end

        def on_arrange_icons_by_authors
            update_arrange_icons_mode(1)
        end

        def on_arrange_icons_by_isbn
            update_arrange_icons_mode(2)
        end

        def on_arrange_icons_by_publisher
            update_arrange_icons_mode(3)
        end

        def on_arrange_icons_by_edition
            update_arrange_icons_mode(4)
        end

        def on_arrange_icons_by_rating
            update_arrange_icons_mode(5)
        end

        def on_arrange_icons_reversed(item)
            Preferences.instance.reverse_icons = item.active? 
            on_refresh
        end

        def on_submit_bug_report
            open_web_browser(BUGREPORT_URL)
        end

        def on_about
            AboutDialog.new(@main_app).show
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
                                _("Check out that a web browser is configured as default (Applications -> Desktop Preferences -> Advanced -> Preferred Applications) and try again."))
            end
        end

        def load_libraries
            @libraries = Library.loadall
        end

        ICON_MAXLEN = 20
        def append_book_as_icon(book)
            icon_title = book.title.sub(/^(.{#{ICON_MAXLEN}}).*$/, '\1...')
            small_cover = Icons.small_cover(selected_library, book)
            @iconlist.append_pixbuf(small_cover, "", icon_title)
        end

        def append_book_in_list(book)
            small_cover = Icons.small_cover(selected_library, book)
            iter = @listview.model.append 
            iter[0] = small_cover.scale(20, 25)
            iter[1] = book.title
            iter[2] = book.authors.join(', ')
            iter[3] = book.isbn
            iter[4] = book.publisher
            iter[5] = book.edition
            rating = (book.rating or Book::DEFAULT_RATING)
            5.times do |i|
                iter[i + 6] = rating >= i.succ ? Icons::STAR_SET : Icons::STAR_UNSET
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
            @listview.model = Gtk::ListStore.new(Gdk::Pixbuf, String, *([String] * 4 + [Gdk::Pixbuf] * 5 + [Integer]))

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
            names = [ _("Authors"), _("ISBN"), _("Publisher"), _("Edition") ]
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
            @treeview_sidepane.model = Gtk::ListStore.new(Gdk::Pixbuf, String, TrueClass)
            @libraries.each { |library| append_library(library) } 
            renderer = Gtk::CellRendererPixbuf.new
            column = Gtk::TreeViewColumn.new(_("Library"))
            column.pack_start(renderer, true)
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
                                        _("The name provided contains the illegal character '<i>%s</i>'.") % match[1])
                    else
                        iter = @treeview_sidepane.model.get_iter(Gtk::TreePath.new(path_string))
                        iter[1] = selected_library.name = new_text
                        on_refresh 
                    end
                end
            end
            @treeview_sidepane.append_column(column)
            @treeview_sidepane.selection.signal_connect('changed') { on_refresh } 
            @treeview_sidepane.selection.select_iter(@treeview_sidepane.model.iter_first) 
        end

        def update_arrange_icons_mode(mode)
            if @prefs.arrange_icons_mode != mode
                @prefs.arrange_icons_mode = mode
                on_refresh
            end
        end 

        def update_filter_books_mode(mode)
            if @filter_books_mode != mode
                @filter_books_mode = mode
                on_refresh unless @filter_entry.text.strip.empty?
            end
        end
       
        def restore_preferences
            if @prefs.maximized
                @main_app.maximize
            else
                @main_app.move(*@prefs.position) unless @prefs.position == [0, 0] 
                @main_app.resize(*@prefs.size)
                @maximized = false
            end
            @paned.position = @prefs.sidepane_position
            @paned.child1.visible = @menu_view_sidepane.active = @prefs.sidepane_visible
            @bonobodock_toolbar.visible = @menu_view_toolbar.active = @prefs.toolbar_visible
            @appbar.visible = @menu_view_statusbar.active = @prefs.statusbar_visible 
            case @prefs.view_as
                when 0
                    @notebook.page = 0 
                    @menu_view_as_icons.active = true
                when 1
                    @notebook.page = 1 
                    @menu_view_as_list.active = true
            end
            unless @prefs.selected_library.nil?
                library = @libraries.find { |x| x.name == @prefs.selected_library }
                select_library(library) unless library.nil?
            end
        end

        def save_preferences
            @prefs.position = @main_app.position
            @prefs.size = @main_app.allocation.to_a[2..3]
            @prefs.maximized = @maximized
            @prefs.sidepane_position = @paned.position
            @prefs.sidepane_visible = @paned.child1.visible?
            @prefs.toolbar_visible = @bonobodock_toolbar.visible?
            @prefs.statusbar_visible = @appbar.visible?
            @prefs.view_as = @notebook.page
            @prefs.selected_library = selected_library.name
        end 
    end
end
end
