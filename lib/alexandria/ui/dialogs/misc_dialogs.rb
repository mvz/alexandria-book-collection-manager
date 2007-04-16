module Alexandria
	module UI
		class ConflictWhileCopyingDialog < AlertDialog
				include GetText
				GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

				def initialize(parent, library, book)
						super(parent, 
									_("The book '%s' already exists in '%s'. Would you like " +
										"to replace it?") % [ book.title, library.name ],
									Gtk::Stock::DIALOG_QUESTION,
									[[_("_Skip"), Gtk::Dialog::RESPONSE_CANCEL],
									 [_("_Replace"), Gtk::Dialog::RESPONSE_OK]],
									_("If you replace the existing book, its contents will " +
										"be overwritten."))
						self.default_response = Gtk::Dialog::RESPONSE_CANCEL
						show_all and @response = run
						destroy
				end

				def replace?
						@response == Gtk::Dialog::RESPONSE_OK
				end
		end

		class ReallyDeleteDialog < AlertDialog
				include GetText
				GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
				
				def initialize(parent, library, books=nil)
						# Deleting a library.
						if books.nil?
								message = _("Are you sure you want to delete '%s'?") \
										% library.name
								description = if library.is_a?(SmartLibrary) \
																 or library.empty?
										nil
								else
										n_("If you continue, %d book will be deleted.",
											 "If you continue, %d books will be deleted.", 
											 library.size) % library.size
								end
						# Deleting books.
						else
								message = if books.length == 1
										_("Are you sure you want to delete '%s' " +
											"from '%s'?") % [ books.first.title, library.name ]
								else
										_("Are you sure you want to delete the " +
											"selected books from '%s'?") % library.name
								end
								description = nil
						end

						super(parent, message, Gtk::Stock::DIALOG_QUESTION,
									[[Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
									 [Gtk::Stock::DELETE, Gtk::Dialog::RESPONSE_OK]],
									description)

						self.default_response = Gtk::Dialog::RESPONSE_CANCEL
						show_all and @response = run
						destroy
				end

				def ok?
						@response == Gtk::Dialog::RESPONSE_OK
				end
		end
	end
end


