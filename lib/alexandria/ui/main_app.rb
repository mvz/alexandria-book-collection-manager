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
        def initialize
            super("main_app.glade")
            @main_app.icon = Icons::ALEXANDRIA_SMALL
            @libraries = Library.loadall
            build_books_listview
            build_sidepane
            on_books_selection_changed
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
                else
                    popup = @book_popup
                    va_icons, va_list = popup.children[-4..-3]
                end
                (@notebook.page == 0 ? va_icons : va_list).active = true
                popup.popup(nil, nil, event.button, event.time) 
            end
        end

        def on_books_selection_changed
            books = selected_books
            @appbar.status = case books.length
                when 0
                    ""
                when 1
                    "'#{books.first.title}' selected"
                else
                    "#{books.length} books selected"
            end
            @popup_properties.sensitive = @menu_properties.sensitive = books.length == 1
            @menu_delete.sensitive = !books.empty? 
        end

        def on_focus(widget, event_focus)
            if widget == @treeview_sidepane
                @menu_properties.sensitive = false
                @menu_delete.sensitive = true
            else
                n = selected_books.length
                @popup_properties.sensitive = @menu_properties.sensitive = n == 1
                @menu_delete.sensitive = n > 0
            end
        end

        def on_book_properties
            books = selected_books
            if books.length == 1
                InfoBookDialog.new(@main_app, selected_library, books.first)
            end
        end

        def on_new_book
            NewBookDialog.new(@main_app, @libraries, selected_library) do |book, library|
                if selected_library == library
                    append_book(book)
                else
                    select_library(library)
                end
            end
        end
     
        def on_new_library
            i = 1
            while true do
                name = "Untitled %d" % i
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
                        "Are you sure you want to permanently delete '#{library.name}'?"
                    when 1
                        "Are you sure you want to permanently delete '#{library.name}', " \
                        "which has one book?"
                    else
                        "Are you sure you want to permanently delete '#{library.name}', " \
                        "which has #{library.length} books?"
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
                    if confirm.call("Are you sure you want to permanently delete '#{book.title}' " \
                                    "from '#{library.name}'?")
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
 
        def on_preferences
            PreferencesDialog.new(@main_app)
        end

        def on_refresh  
            @listview.model.clear
            @iconlist.clear
            library = selected_library
            library.each { |book| append_book(book) }
            @main_app.title = library.name + " - " + TITLE
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
            if widget.name.include?('popup_view_as_icons') or widget == @menu_view_as_icons
                @toolbar_view_as.menu.active = @toolbar_view_as.history = 0
            end
            if widget.name.include?('popup_view_as_icons') or widget == @toolbar_view_as_icons
                @menu_view_as_icons.active = true
            end
        end

        def on_view_as_list(widget)
            @notebook.page = 1
            if widget.name.include?('popup_view_as_list') or widget == @menu_view_as_list
                @toolbar_view_as.menu.active = @toolbar_view_as.history = 1
            end
            if widget.name.include?('popup_view_as_list') or widget == @toolbar_view_as_list
                @menu_view_as_list.active = true
            end
        end

        def on_about
            AboutDialog.new(@main_app).show
        end

        #######
        private
        #######

        ICON_MAXLEN = 20
        def append_book(book)
            icon_title = book.title.length > ICON_MAXLEN ? book.title[0..ICON_MAXLEN] + '...' : book.title
            small_cover = selected_library.small_cover(book)
            @iconlist.append(small_cover, icon_title)
            iter = @listview.model.append 
            iter[0] = Gdk::Pixbuf.new(small_cover).scale(25, 25)
            iter[1] = book.title
            iter[2] = book.authors.join(', ')
            iter[3] = book.isbn
            iter[4] = book.publisher
            iter[5] = book.edition
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
            model = Gtk::ListStore.new(Gdk::Pixbuf, String, String, String, String, String)
            @listview.model = model

            # first column
            renderer = Gtk::CellRendererPixbuf.new
            column = Gtk::TreeViewColumn.new("Title")
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
            names = %w{Authors ISBN Publisher Edition}
            names.each_index do |i|
                column = Gtk::TreeViewColumn.new(names[i], renderer, :text => i + 2)
                column.resizable = true
                column.sort_column_id = i + 2
                @listview.append_column(column)
            end

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
            column = Gtk::TreeViewColumn.new("Library")
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
                                        "Invalid library name '#{new_text}'",
                                        "The name provided contains the illegal character '<i>#{match[1]}</i>'.")
                    else
                        iter = @treeview_sidepane.model.get_iter(Gtk::TreePath.new(path_string))
                        selected_library.name = new_text
                        iter[1] = new_text
                    end
                end
            end
            @treeview_sidepane.append_column(column)
            @treeview_sidepane.selection.signal_connect('changed') { on_refresh } 
            @treeview_sidepane.selection.select_iter(@treeview_sidepane.model.iter_first) 
        end
    end
end
end
