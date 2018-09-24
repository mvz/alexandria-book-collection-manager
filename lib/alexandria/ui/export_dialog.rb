# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/export_format"
require "alexandria/ui/confirm_erase_dialog"
require "alexandria/ui/error_dialog"

module Alexandria
  module UI
    class ExportDialog
      include GetText
      extend GetText

      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      FORMATS = Alexandria::ExportFormat.all
      THEMES = Alexandria::WebTheme.all

      attr_reader :dialog

      def initialize(parent, library, sort_order)
        @dialog = Gtk::FileChooserDialog.new(_("Export '%s'") % library.name,
                                             parent,
                                             :save,
                                             [[Gtk::STOCK_HELP, :help],
                                              [Gtk::STOCK_CANCEL, :cancel],
                                              [_("_Export"), :accept]])
        @dialog.current_name = library.name
        @dialog.signal_connect("destroy") { @dialog.hide }

        @parent = parent
        @library = library
        @sort_order = sort_order

        preview_image = Gtk::Image.new

        @theme_combo = Gtk::ComboBoxText.new
        @theme_combo.valign = :center
        @theme_combo.vexpand = false
        THEMES.each do |theme|
          @theme_combo.append_text(theme.name)
        end
        @theme_combo.signal_connect("changed") do
          file = THEMES[@theme_combo.active].preview_file
          preview_image.set_from_file file
        end
        @theme_combo.active = 0
        theme_label = Gtk::Label.new_with_mnemonic _("_Theme:")
        theme_label.xalign = 0
        theme_label.mnemonic_widget = @theme_combo

        @types_combo = Gtk::ComboBoxText.new
        @types_combo.vexpand = false
        @types_combo.valign = :center
        FORMATS.each do |format|
          text = format.name + " ("
          text += if format.ext
                    "*." + format.ext
                  else
                    _("directory")
                  end
          text += ")"
          @types_combo.append_text(text)
        end
        @types_combo.active = 0
        @types_combo.signal_connect("changed") do
          visible = FORMATS[@types_combo.active].needs_preview?
          theme_label.visible = @theme_combo.visible = preview_image.visible = visible
        end
        @types_combo.show

        types_label = Gtk::Label.new_with_mnemonic _("Export for_mat:")
        types_label.xalign = 0
        types_label.mnemonic_widget = @types_combo
        types_label.show

        # TODO: Re-design extra widget layout
        grid = Gtk::Grid.new
        grid.column_spacing = 6
        grid.attach types_label, 0, 0, 1, 1
        grid.attach @types_combo, 1, 0, 1, 1
        grid.attach theme_label, 0, 1, 1, 1
        grid.attach @theme_combo, 1, 1, 1, 1
        grid.attach preview_image, 2, 0, 1, 3
        @dialog.set_extra_widget grid
      end

      def perform
        while ((response = dialog.run) != Gtk::ResponseType::CANCEL) &&
            (response != Gtk::ResponseType::DELETE_EVENT)

          if response == Gtk::ResponseType::HELP
            Alexandria::UI.display_help(self, "exporting")
          else
            begin
              break if on_export(FORMATS[@types_combo.active],
                                 THEMES[@theme_combo.active])
            rescue StandardError => ex
              ErrorDialog.new(@dialog, _("Export failed"), ex.message).display
              break
            end
          end
        end
        dialog.destroy
      end

      private

      def on_export(format, theme)
        filename = dialog.filename
        if format.ext
          filename += "." + format.ext if File.extname(filename).empty?
          if File.exist?(filename)
            dialog = ConfirmEraseDialog.new(@dialog, filename)
            return unless dialog.erase?

            FileUtils.rm(filename)
          end
          args = []
        else
          if File.exist?(filename)
            unless File.directory?(filename)
              msg = _("The target, named '%s', is a regular " \
                      "file.  A directory is needed for this " \
                      "operation.  Please select a directory and " \
                      "try again.") % filename
              ErrorDialog.new(@dialog, _("Not a directory"), msg).display
              return
            end
          else
            Dir.mkdir(filename)
          end
          args = [theme]
        end
        format.invoke(@library, @sort_order, filename, *args)
        true
      end
    end
  end
end
