module Alexandria
module UI
    class MainApp < GladeBase 
        def initialize
            super("main_app.glade")
            @default_list = BookList.load("My Library")
            @default_list.each { |book| append_book(book) }

            model = Gtk::TreeStore.new(Gdk::Pixbuf, String)
            root = model.append(nil)
            root[0] = @main_app.render_icon(Gtk::Stock::HOME,
                                            Gtk::IconSize::SMALL_TOOLBAR,
                                            "home_icon")
            root[1] = "Home"
            default = model.append(root)
            default[0] = nil
            default[1] = @default_list.name
            
            @treeview_libraries.model = model
            renderer = Gtk::CellRendererPixbuf.new
            @treeview_libraries.insert_column(-1, "Blah", renderer, :pixbuf => 0)
            renderer = Gtk::CellRendererText.new
            @treeview_libraries.insert_column(-1, "Blah", renderer, :text => 1)
            @treeview_libraries.expand_all
        end

        def on_select_icon(gii, n, event)
            if event
                # double left click
                if event.event_type == Gdk::Event::BUTTON2_PRESS and
                   event.button == 1 

                    InfoBookDialog.new(@main_app, @default_list[n])
                end

                # right click
                if event.event_type == Gdk::Event::BUTTON_PRESS and
                   event.button == 3

                    p "right click" 
                end
            end
        end

        def on_new_book
            NewBookDialog.new(@main_app) do |book|
                @default_list << book
                @default_list.save
                append_book(book)
            end
        end
     
        def on_new_book_list
        end
    
        def on_quit
            Gtk.main_quit
        end
   
        def on_delete
        end
 
        def on_preferences
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
   
        def on_home
        end
 
        def on_about
            AboutDialog.new.show
        end

        private
        def append_book(book)
            @iconlist.append(book.small_cover, book.title) 
        end
    end
end
end
