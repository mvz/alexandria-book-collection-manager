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
 
        def on_books_mouse_event(widget, event)
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
                else
                    popup = @book_popup
                    # disable 'property' in case of multiple selections
                    popup.children.first.sensitive = books.length == 1
                end
                popup.popup(nil, nil, event.button, event.time) 
            end
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
 
        def on_view_as_icons
            @notebook.page = @toolbar_view_as.menu.active = 0
            # FIXME the OptionMenu doesn't refresh itself 
        end

        def on_view_as_icons2
            @notebook.page = 0 
            @menu_view_as_icons.active = true
        end

        def on_view_as_list
            @notebook.page = @toolbar_view_as.menu.active = 1
            # FIXME the OptionMenu doesn't refresh itself 
        end

        def on_view_as_list2
            @notebook.page = 1 
            @menu_view_as_list.active = true
        end

        def on_sort_title
        end
        
        def on_sort_authors
        end
        
        def on_sort_isbn
        end
        
        def on_sort_publisher
        end
 
        def on_sort_edition
        end

        def on_go_up
        end

        def on_home
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
            model = Gtk::ListStore.new(Gdk::Pixbuf, String)
            @libraries.each do |library|
                iter = model.append
                iter[0] = Icons::LIBRARY_SMALL
                iter[1] = library.name
            end
            @treeview_sidepane.model = model
            renderer = Gtk::CellRendererPixbuf.new
            @treeview_sidepane.insert_column(-1, "Icon", renderer, :pixbuf => 0)
            renderer = Gtk::CellRendererText.new
            @treeview_sidepane.insert_column(-1, "Name", renderer, :text => 1)
            @treeview_sidepane.selection.signal_connect('changed') { on_refresh } 
            @treeview_sidepane.selection.select_iter(model.iter_first) 
        end
    end
end
end
