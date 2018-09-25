# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require 'alexandria/export_format'

module Alexandria
  module UI
    class ConfirmEraseDialog < AlertDialog
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: 'UTF-8')

      def initialize(parent, filename)
        super(parent, _('File already exists'),
              Gtk::Stock::DIALOG_QUESTION,
              [[Gtk::Stock::CANCEL, :cancel],
               [_('_Replace'), :ok]],
              _("A file named '%s' already exists.  Do you want " \
                'to replace it with the one you are generating?') % filename)
        # FIXME: Should accept just :cancel
        self.default_response = Gtk::ResponseType::CANCEL
      end

      def erase?
        show_all && (@response = run)
        destroy
        @response == Gtk::ResponseType::OK
      end
    end

    class ExportDialog < SimpleDelegator
      include GetText
      extend GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: 'UTF-8')

      FORMATS = Alexandria::ExportFormat.all
      THEMES = Alexandria::WebTheme.all

      def initialize(parent, library, sort_order)
        @export_dialog = Gtk::FileChooserDialog.new(title: _("Export '%s'") % library.name,
                                                    parent: parent,
                                                    action: :save,
                                                    buttons: [[Gtk::Stock::HELP, :help],
                                                              [Gtk::Stock::CANCEL, :cancel],
                                                              [_('_Export'), :accept]])
        super(@export_dialog)

        self.current_name = library.name
        signal_connect('destroy') { hide }

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
        @theme_combo.signal_connect('changed') do
          file = THEMES[@theme_combo.active].preview_file
          preview_image.pixbuf = GdkPixbuf::Pixbuf.new(file: file)
        end
        @theme_combo.active = 0
        theme_label = Gtk::Label.new(_('_Theme:'), use_underline: true)
        theme_label.xalign = 0
        theme_label.mnemonic_widget = @theme_combo

        @types_combo = Gtk::ComboBoxText.new
        @types_combo.vexpand = false
        @types_combo.valign = :center
        FORMATS.each do |format|
          text = format.name + ' ('
          text += if format.ext
                    '*.' + format.ext
                  else
                    _('directory')
                  end
          text += ')'
          @types_combo.append_text(text)
        end
        @types_combo.active = 0
        @types_combo.signal_connect('changed') do
          visible = FORMATS[@types_combo.active].needs_preview?
          theme_label.visible = @theme_combo.visible = preview_image.visible = visible
        end
        @types_combo.show

        types_label = Gtk::Label.new(_('Export for_mat:'), use_underline: true)
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
        set_extra_widget grid
      end

      def perform
        while ((response = run) != Gtk::ResponseType::CANCEL) &&
            (response != Gtk::ResponseType::DELETE_EVENT)

          if response == Gtk::ResponseType::HELP
            Alexandria::UI.display_help(self, 'exporting')
          else
            begin
              break if on_export(FORMATS[@types_combo.active],
                                 THEMES[@theme_combo.active])
            rescue StandardError => e
              ErrorDialog.new(@export_dialog, _('Export failed'), e.message).display
            end
          end
        end
        destroy
      end

      private

      def on_export(format, theme)
        raise NotImplementedError unless @library.respond_to?(format.message)

        filename = self.filename
        if format.ext
          filename += '.' + format.ext if File.extname(filename).empty?
          if File.exist?(filename)
            dialog = ConfirmEraseDialog.new(@export_dialog, filename)
            return unless dialog.erase?

            FileUtils.rm(filename)
          end
          args = []
        else
          if File.exist?(filename)
            unless File.directory?(filename)
              msg = _("The target, named '%s', is a regular " \
                      'file.  A directory is needed for this ' \
                      'operation.  Please select a directory and ' \
                      'try again.') % filename
              ErrorDialog.new(@export_dialog, _('Not a directory'), msg).display
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
