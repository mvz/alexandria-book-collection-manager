# Copyright (C) 2004-2006 Laurent Sansonetti
#
# Alexandria is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# Alexandria is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with Alexandria; see the file COPYING.  If not,
# write to the Free Software Foundation, Inc., 51 Franklin Street,
# Fifth Floor, Boston, MA 02110-1301 USA.

module Alexandria
  module UI
    class ConfirmEraseDialog < AlertDialog
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      def initialize(parent, filename)
        super(parent, _("File already exists"),
              Gtk::Stock::DIALOG_QUESTION,
              [[Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
               [_("_Replace"), Gtk::Dialog::RESPONSE_OK]],
              _("A file named '%s' already exists.  Do you want " +
                "to replace it with the one you are generating?") \
              % filename)
        self.default_response = Gtk::Dialog::RESPONSE_CANCEL
        show_all and @response = run
        destroy
      end

      def erase?
        @response == Gtk::Dialog::RESPONSE_OK
      end
    end

    class ExportDialog < Gtk::FileChooserDialog
      include GetText
      extend GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, :charset => "UTF-8")

      FORMATS = Alexandria::ExportFormat.all
      THEMES = Alexandria::WebTheme.all

      def initialize(parent, library, sort_order)
        backend = `uname`.chomp == "FreeBSD" ? "neant" : "gnome-vfs"
        super(_("Export '%s'") % library.name,
              nil,
              Gtk::FileChooser::ACTION_SAVE,
              backend,
              [Gtk::Stock::HELP, Gtk::Dialog::RESPONSE_HELP],
              [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
              [_("_Export"), Gtk::Dialog::RESPONSE_ACCEPT])

        self.transient_for = parent
        self.current_name = library.name
        self.signal_connect('destroy') { hide }

        @parent, @library, @sort_order = parent, library, sort_order

        preview_image = Gtk::Image.new

        theme_combo = Gtk::ComboBox.new
        THEMES.each do |theme|
          theme_combo.append_text(theme.name)
        end
        theme_combo.signal_connect('changed') do
          file = THEMES[theme_combo.active].preview_file
          preview_image.pixbuf = Gdk::Pixbuf.new(file)
        end
        theme_combo.active = 0
        theme_label = Gtk::Label.new(_("_Theme:"), true)
        theme_label.xalign = 0
        theme_label.mnemonic_widget = theme_combo

        types_combo = Gtk::ComboBox.new
        FORMATS.each do |format|
          text = format.name + " ("
          if format.ext
            text += "*." + format.ext
          else
            text += _("directory")
          end
          text += ")"
          types_combo.append_text(text)
        end
        types_combo.active = 0
        types_combo.signal_connect('changed') do
          theme_label.visible = theme_combo.visible =
            preview_image.visible =
            FORMATS[types_combo.active].needs_preview?
        end
        types_combo.show

        types_label = Gtk::Label.new(_("Export for_mat:"), true)
        types_label.xalign = 0
        types_label.mnemonic_widget = types_combo
        types_label.show

        # Ugly hack to add more rows in the internal Gtk::Table of the
        # widget, which is needed because we want the export type to be
        # aligned against the other widgets, and #extra_widget doesn't do
        # that...
        internal_table =
          children[0].children[0].children[0].children[0].children[0]
        internal_table.resize(4, 3)
        internal_table.attach(types_label, 0, 1, 2, 3)
        internal_table.attach(types_combo, 1, 2, 2, 3)
        internal_table.attach(theme_label, 0, 1, 3, 4)
        internal_table.attach(theme_combo, 1, 2, 3, 4)
        internal_table.attach(preview_image, 2, 3, 0, 4)

        while (response = run) != Gtk::Dialog::RESPONSE_CANCEL and
            response != Gtk::Dialog::RESPONSE_DELETE_EVENT

          if response == Gtk::Dialog::RESPONSE_HELP
            Alexandria::UI::display_help(self, 'exporting')
          else
            begin
              break if on_export(FORMATS[types_combo.active],
                                 THEMES[theme_combo.active])
            rescue => e
              ErrorDialog.new(self, _("Export failed"), e.message)
            end
          end
        end
        destroy
      end

      #######
      private
      #######

      def on_export(format, theme)
        unless @library.respond_to?(format.message)
          raise NotImplementedError
        end
        filename = self.filename
        if format.ext
          filename += "." + format.ext if File.extname(filename).empty?
          if File.exists?(filename)
            dialog = ConfirmEraseDialog.new(@parent, filename)
            return unless dialog.erase?
            FileUtils.rm(filename)
          end
          args = []
        else
          if File.exists?(filename)
            unless File.directory?(filename)
              msg = _("The target, named '%s', is a regular " +
                      "file.  A directory is needed for this " +
                      "operation.  Please select a directory and " +
                      "try again.") % filename
              ErrorDialog.new(@parent, _("Not a directory"), msg)
              return
            end
          else
            Dir.mkdir(filename)
          end
          args = [theme]
        end
        format.invoke(@library, @sort_order, filename, *args)
        return true
      end
    end
  end
end
