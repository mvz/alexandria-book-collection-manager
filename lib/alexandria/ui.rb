require 'libglade2'
require 'gnome2'

require 'alexandria/ui/glade_base.rb'
require 'alexandria/ui/error_dialog.rb'
require 'alexandria/ui/about_dialog.rb'
require 'alexandria/ui/info_book_dialog.rb'
require 'alexandria/ui/new_book_dialog.rb'
require 'alexandria/ui/main_app.rb'

module Alexandria
module UI
    def self.main
        Gnome::Program.new(TITLE, VERSION)
        MainApp.new
        Gtk.main
    end
end
end
