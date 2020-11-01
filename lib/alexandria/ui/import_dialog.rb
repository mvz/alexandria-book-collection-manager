# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/error_dialog"
require "alexandria/ui/skip_entry_dialog"

module Alexandria
  module UI
    class ImportDialog
      include GetText
      include Logging

      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      FILTERS = Alexandria::ImportFilter.all

      attr_reader :dialog

      def initialize(parent)
        title = _("Import a Library")
        @dialog = Gtk::FileChooserDialog.new title, parent, :open, []
        log.debug { "ImportDialog opened" }
        @destroyed = false
        @running = false
        dialog.add_button(Gtk::STOCK_HELP, Gtk::ResponseType::HELP)
        dialog.add_button(Gtk::STOCK_CANCEL, Gtk::ResponseType::CANCEL)
        import_button = dialog.add_button(_("_Import"),
                                          Gtk::ResponseType::ACCEPT)
        import_button.sensitive = false

        dialog.signal_connect("destroy") do
          if @running
            @destroyed = true
          else
            dialog.destroy
          end
        end

        @filters = {}
        FILTERS.each do |filter|
          filefilter = make_filefilter filter
          dialog.add_filter(filefilter)
          log.debug { "Added ImportFilter #{filefilter} -- #{filefilter.name}" }
          @filters[filefilter.name] = filter
        end

        dialog.signal_connect("selection-changed") do
          import_button.sensitive = dialog.filename && File.file?(dialog.filename)
        end

        # before adding the (hidden) progress bar, we must re-set the
        # packing of the button box (currently packed at the end),
        # because the progressbar will be *after* the button box.
        box = dialog.content_area
        buttonbox = box.children.to_a.last
        expand, fill, padding, _pack_type = box.query_child_packing buttonbox
        box.set_child_packing(buttonbox, expand, fill, padding, :start)
        box.reorder_child(buttonbox, 1)

        @pbar = Gtk::ProgressBar.new
        @pbar.show_text = true
        box.pack_start(@pbar, false, false, 0)
      end

      def acquire
        on_progress = proc do |fraction|
          @pbar.show unless @pbar.visible
          @pbar.fraction = fraction
        end

        on_error = proc do |message|
          SkipEntryDialog.new(self, message).continue?
        end

        exec_queue = ExecutionQueue.new

        while !@destroyed &&
            ((response = dialog.run) != Gtk::ResponseType::CANCEL) &&
            response != Gtk::ResponseType::DELETE_EVENT

          if response == Gtk::ResponseType::HELP
            Alexandria::UI.display_help(self, "import-library")
            next
          end
          file = File.basename(dialog.filename, ".*")
          # FIXME: Should just return a string
          base, = GLib.locale_to_utf8(file)
          new_library_name = Library.generate_new_name(
            LibraryCollection.instance.all_libraries,
            base)

          filter = @filters[dialog.filter.name]
          log.debug { "Going forward with filter: #{filter.name}" }
          dialog.sensitive = false

          filter.on_iterate do |n, total|
            unless @destroyed
              fraction = n * 1.0 / total
              log.debug { "#{inspect} fraction: #{fraction}" }
              exec_queue.call(on_progress, fraction)
            end
          end

          not_cancelled = true
          filter.on_error do |message|
            not_cancelled = exec_queue.sync_call(on_error, message)
            log.debug { "#{inspect} cancel state: #{not_cancelled}" }
          end

          library = nil
          @bad_isbns = nil
          @failed_isbns = nil
          thread = Thread.start do
            library, @bad_isbns, @failed_isbns =
              filter.invoke(new_library_name, dialog.filename)
          rescue StandardError => ex
            trace = ex.backtrace.join("\n> ")
            log.error { "Import failed: #{ex.message} #{trace}" }
          end

          while thread.alive? && !@destroyed
            @running = true
            exec_queue.iterate
            Gtk.main_iteration_do(false)
          end

          unless @destroyed
            if library
              yield(library, @bad_isbns, @failed_isbns)
              break
            elsif not_cancelled
              log.debug { "Raising ErrorDialog because not_cancelled is #{not_cancelled}" }
              ErrorDialog.new(dialog,
                              _("Couldn't import the library"),
                              _("The format of the file you " \
                                "provided is unknown.  Please " \
                                "retry with another file.")).display
            end
            @pbar.hide
            self.sensitive = true
          end
        end

        dialog.destroy unless @destroyed
      end

      private

      def make_filefilter(import_filter)
        filefilter = Gtk::FileFilter.new
        filefilter.name = import_filter.name
        import_filter.patterns.each { |x| filefilter.add_pattern(x) }
        filefilter
      end
    end
  end
end
