# HIG compliant error dialog box
module Alexandria
module UI
    class ErrorDialog < Gtk::Dialog
        def initialize(parent, title, message=nil)
            super("", parent, Gtk::Dialog::DESTROY_WITH_PARENT,
                  [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_OK])

            self.border_width = 6
            self.resizable = false
            self.has_separator = false
            self.default_response = Gtk::Dialog::RESPONSE_OK
            self.vbox.spacing = 12

            hbox = Gtk::HBox.new(false, 12)
            hbox.border_width = 6
            self.vbox.pack_start(hbox)

            image = Gtk::Image.new(Gtk::Stock::DIALOG_ERROR,
                                   Gtk::IconSize::DIALOG)
            image.set_alignment(0.5, 0)
            hbox.pack_start(image)

            vbox = Gtk::VBox.new(false, 6)
            hbox.pack_start(vbox)

            label = Gtk::Label.new
            label.set_alignment(0.5, 0)
            label.wrap = true
            label.markup = "<b><big>#{title}</big></b>"
            vbox.pack_start(label)

            if message
                label = Gtk::Label.new(message.strip)
                label.set_alignment(0.5, 0)
                label.wrap = true
                vbox.pack_start(label)
            end
            show_all and run
            destroy
        end
    end
end
end
