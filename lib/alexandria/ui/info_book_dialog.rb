module Alexandria
module UI
    class InfoBookDialog < GladeBase
        def initialize(parent, book)
            super('info_book_dialog.glade')
            @info_book_dialog.transient_for = parent
            @image_cover.file = book.medium_cover
            @label_title.text = @info_book_dialog.title = book.title
            @label_authors.text = book.authors.join("\n")
            @label_isbn.text = book.isbn
            @label_publisher.text = book.publisher
            @label_edition.text = book.edition
        end

        def on_close
            @info_book_dialog.destroy
        end
    end
end
end
