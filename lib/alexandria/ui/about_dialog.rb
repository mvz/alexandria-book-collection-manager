module Alexandria
module UI
    class AboutDialog < Gnome::About
        def initialize
            super(Alexandria::TITLE,
                  Alexandria::VERSION,
                  Alexandria::COPYRIGHT,
                  Alexandria::DESCRIPTION,
                  Alexandria::AUTHORS,
                  Alexandria::DOCUMENTERS,
                  Alexandria::TRANSLATORS.join("\n"),
                  nil)
            signal_connect('destroy') { hide }
        end
    end
end
end
