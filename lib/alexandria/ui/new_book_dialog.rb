module Alexandria
module UI
    class NewBookDialog < GladeBase
        def initialize(parent, &block)
            super('new_book_dialog.glade')
            @new_book_dialog.transient_for = @parent = parent
            @block = block
        end
    
        def on_changed(entry)
            raise unless entry.is_a?(Gtk::Entry)
            @button_find.sensitive = !entry.text.strip.empty?
        end
    
        def on_add
            begin
                book = Alexandria::BookProvider.find(@entry_isbn.text)
                @new_book_dialog.destroy
                @block.call(book)
            rescue Errno::EINVAL
                # For a strange reason it seems that the first request always fails
                # on FreeBSD.
                retry
            rescue => e
                ErrorDialog.new(@parent,
                                "Could not add the book '#{@entry_isbn.text}'",
                                e.message)
            end
        end
    
        def on_cancel
            @new_book_dialog.destroy
        end
    end
end
end
