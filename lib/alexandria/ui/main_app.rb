module Alexandria
module UI
    class MainApp < GladeBase 
        def initialize
            super("main_app.glade")
            @default_list = BookList.load("My Library")
            @default_list.each { |book| append_book(book) }
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
    
        def on_view_toolbar
        end
    
        def on_view_statusbar
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
