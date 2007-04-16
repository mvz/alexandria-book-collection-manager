module Alexandria
	module UI
		# Generalized Dialog for lists of bad isbns. Used for on_import. Can also
		# be used for on_load library conversions.
		class BadIsbnsDialog < Gtk::MessageDialog
			def initialize(parent, message=nil, list = nil)
				message = _("There's a problem" ) unless message
				super(parent, Gtk::Dialog::MODAL, Gtk::MessageDialog::WARNING,  Gtk::MessageDialog::BUTTONS_CLOSE, message)
				isbn_container = Gtk::HBox.new
				the_vbox = self.children.first
				the_vbox.pack_start(isbn_container)
				the_vbox.reorder_child(isbn_container, 3)
				scrolley = Gtk::ScrolledWindow.new
				isbn_container.pack_start(scrolley)
				textview = Gtk::TextView.new(Gtk::TextBuffer.new)
				textview.editable = false
				textview.cursor_visible = false
				scrolley.add(textview)
				list.each do |li|
					textview.buffer.insert_at_cursor("#{li}\n")
				end
				show_all
			end
		end
	end
end
