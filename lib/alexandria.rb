require 'alexandria/config.rb'
require 'alexandria/book.rb'
require 'alexandria/ui.rb'

module Alexandria
    TITLE = 'Alexandria'
    VERSION = '0.1.1'
    DESCRIPTION = 'A program to help you manage your book collection.'
    COPYRIGHT = 'Copyright (C) 2004 Laurent Sansonetti'
    AUTHORS = [ 'Laurent Sansonetti <lrz@gnome.org>' ]
    DOCUMENTERS = [ 'Laurent Sansonetti <lrz@gnome.org>' ]  
    TRANSLATORS = [ 'Laurent Sansonetti <lrz@gnome.org>' ]
    LIST = 'alexandria-list@rubyforge.org'

    def self.main
        Alexandria::UI.main
    end
end
