module Alexandria
  def self.list_books_on_console(title = true, authors=true)
    libraries_simpleton = Alexandria::Libraries.instance
    libraries_simpleton.reload
    libraries = Alexandria::Library.loadall
    output_string = ""
    @books = libraries.flatten
    @books.each do |book|
      book_authors = book.authors.join(" & ") if authors      
      output_string += [book.title, book_authors].join(", ") + "\n"
    end
    output_string
  end
end
