module Alexandria
module UI
    class NewBookDialog < GladeBase
        def initialize(parent, libraries, selected_library=nil, &block)
            super('new_book_dialog.glade')
            @new_book_dialog.transient_for = @parent = parent
            @block = block
            @libraries = libraries
            popdown = libraries.map { |x| x.name }
            if selected_library
              popdown.delete selected_library.name
              popdown.unshift selected_library.name
            end
            @combo_libraries.popdown_strings = popdown
            @combo_libraries.sensitive = libraries.length > 1
        end
    
        def on_changed(entry)
            raise unless entry.is_a?(Gtk::Entry)
            @button_find.sensitive = !entry.text.strip.empty?
        end
    
        def on_add
            begin
                library = @libraries.find { |x| x.name == @combo_libraries.entry.text }
                if book = library.find { |book| book.isbn == @entry_isbn.text }
                    raise "'#{book.isbn}' already exists in '#{library.name}' (titled '#{book.title}')."
                end
                book = Alexandria::BookProvider.find(@entry_isbn.text)
                @new_book_dialog.destroy
                @block.call(book, library)
            rescue Errno::EINVAL
                # For a strange reason it seems that the first request always fails
                # on FreeBSD.
                retry
            rescue => e
                ErrorDialog.new(@parent, "Couldn't add book", e.message)
            end
        end
    
        def on_cancel
            @new_book_dialog.destroy
        end
    end
end
end
