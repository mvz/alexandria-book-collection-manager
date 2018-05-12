# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require 'observer'
require 'singleton'

module Alexandria
  class LibraryCollection
    attr_reader :all_libraries, :ruined_books, :deleted_books
    attr_accessor :library_store

    include Observable
    include Singleton

    def reload
      @all_libraries.clear
      @all_libraries.concat(library_store.load_all_libraries)
      @all_libraries.concat(SmartLibrary.loadall)

      ruined = []
      deleted = []
      all_regular_libraries.each { |library|
        ruined += library.ruined_books
        # make deleted books from each library accessible so we don't crash on smart libraries
        deleted += library.deleted_books
      }
      @ruined_books = ruined
      @deleted_books = deleted
    end

    def all_regular_libraries
      @all_libraries.select { |x| x.is_a?(Library) }
    end

    def all_smart_libraries
      @all_libraries.select { |x| x.is_a?(SmartLibrary) }
    end

    LIBRARY_ADDED = 1
    LIBRARY_REMOVED = 2

    def add_library(library)
      @all_libraries << library
      notify(LIBRARY_ADDED, library)
    end

    def remove_library(library)
      @all_libraries.delete(library)
      notify(LIBRARY_REMOVED, library)
    end

    def really_delete_deleted_libraries
      Library.really_delete_deleted_libraries
      SmartLibrary.really_delete_deleted_libraries
    end

    def really_save_all_books
      all_regular_libraries.each do |library|
        library.each { |book| library.save(book, true) }
      end
    end

    private

    def initialize
      @all_libraries = []
      @deleted_books = []
    end

    def notify(action, library)
      changed
      notify_observers(self, action, library)
    end
  end
end
