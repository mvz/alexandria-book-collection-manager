module Alexandria
module UI
    class MainApp < GladeBase 
        def initialize
            super("main_app.glade")
            @main_app.icon = Icons::ALEXANDRIA_SMALL
            @libraries = Library.loadall
            build_books_listview
            build_sidepane
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
        end

        def on_book_properties
            books = selected_books
            if books.length == 1
                InfoBookDialog.new(@main_app, books.first)
            end
        end

        def on_new_book
            NewBookDialog.new(@main_app, @libraries) do |book, library|
                library << book
                library.save
                append_book(book)
            end
        end
     
        def on_new_library
        end
    
        def on_quit
            Gtk.main_quit
        end
   
        def on_delete
            library = selected_library
            selected_books.each do |book|
                dialog = AlertDialog.new(@main_app,
                                         "Are you sure you want to permanently " \
                                         "delete '#{book.title}' from '#{library.name}'?",
                                         Gtk::Stock::DIALOG_QUESTION,
                                         [[Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                          [Gtk::Stock::DELETE, Gtk::Dialog::RESPONSE_OK]])
                dialog.default_response = Gtk::Dialog::RESPONSE_CANCEL
                dialog.show_all
                if dialog.run == Gtk::Dialog::RESPONSE_OK
                    library.delete(book)
                end
                dialog.destroy
            end
            on_refresh
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
        end

        def on_refresh
            @listview.model.clear
            @iconlist.clear
            selected_library.each { |book| append_book(book) }
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
                @toolbar_view_as.menu.active = 0
                # FIXME the OptionMenu doesn't refresh itself 
            end
            if widget.name.include?('popup_view_as_icons') or widget == @toolbar_view_as_icons
                @menu_view_as_icons.active = true
            end
        end

        def on_view_as_list(widget)
            @notebook.page = 1
            if widget.name.include?('popup_view_as_list') or widget == @menu_view_as_list
                @toolbar_view_as.menu.active = 1
                # FIXME the OptionMenu doesn't refresh itself 
            end
            if widget.name.include?('popup_view_as_list') or widget == @toolbar_view_as_list
                @menu_view_as_list.active = true
            end
        end

        def on_about
            AboutDialog.new.show
        end

        #######
        private
        #######

        def append_book(book)
            @iconlist.append(book.small_cover, book.title)
            iter = @listview.model.append 
            iter[0] = Gdk::Pixbuf.new(book.small_cover).scale(25, 25)
            iter[1] = book.title
            iter[2] = book.authors.join(', ')
            iter[3] = book.isbn
            iter[4] = book.publisher
            iter[5] = book.edition
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
                p cell
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
            iter = @treeview_sidepane.selection.selected
            @libraries.find { |x| x.name == iter[1] }
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
            model = Gtk::ListStore.new(Gdk::Pixbuf, String, TrueClass)
            @libraries.each do |library|
                iter = model.append
                iter[0] = Icons::LIBRARY_SMALL
                iter[1] = library.name
                iter[2] = true
            end
            @treeview_sidepane.model = model
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
                    iter = model.get_iter(Gtk::TreePath.new(path_string))
                    selected_library.name = new_text
                    iter[1] = new_text
                end
            end
            @treeview_sidepane.append_column(column)
            @treeview_sidepane.selection.signal_connect('changed') { on_refresh } 
            @treeview_sidepane.selection.select_iter(model.iter_first) 
        end
    end
end
end
