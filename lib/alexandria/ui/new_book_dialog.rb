module Alexandria
module UI
    class NewBookDialog < GladeBase
        def initialize(parent, libraries, &block)
            super('new_book_dialog.glade')
            @new_book_dialog.transient_for = @parent = parent
            @block = block
            @libraries = libraries
            @combo_libraries.popdown_strings = libraries.map { |x| x.name }
            @combo_libraries.sensitive = libraries.length > 1
        end
    
        def on_changed(entry)
            raise unless entry.is_a?(Gtk::Entry)
            @button_find.sensitive = !entry.text.strip.empty?
        end
    
        def on_add
            begin
                book = Alexandria::BookProvider.find(@entry_isbn.text)
                library = @libraries.delete_if { |x| x.name != @combo_libraries.entry.text }.first
                @new_book_dialog.destroy
                @block.call(book, library)
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
