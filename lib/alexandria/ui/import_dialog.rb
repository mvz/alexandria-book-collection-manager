# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "alexandria/ui/error_dialog"
require "alexandria/ui/skip_entry_dialog"

class Alexandria::ImportFilter
  def to_filefilter
    filefilter = Gtk::FileFilter.new
    filefilter.name = name
    patterns.each { |x| filefilter.add_pattern(x) }
    filefilter
  end
end

module Alexandria
  module UI
    class ImportDialog < SimpleDelegator
      include GetText
      include Logging

      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: "UTF-8")

      FILTERS = Alexandria::ImportFilter.all

      def initialize(parent)
        title = _("Import a Library")
        dialog = Gtk::FileChooserDialog.new title: title, parent: parent, action: :open
        super(dialog)
        puts "ImportDialog opened." if $DEBUG
        @destroyed = false
        @running = false
        add_button(Gtk::Stock::HELP, Gtk::ResponseType::HELP)
        add_button(Gtk::Stock::CANCEL, Gtk::ResponseType::CANCEL)
        import_button = add_button(_("_Import"),
                                   Gtk::ResponseType::ACCEPT)
        import_button.sensitive = false

        signal_connect("destroy") do
          if @running
            @destroyed = true
          else
            destroy
          end
        end

        filters = {}
        FILTERS.each do |filter|
          filefilter = filter.to_filefilter
          add_filter(filefilter)
          puts "Added ImportFilter #{filefilter} -- #{filefilter.name}" if $DEBUG
          filters[filefilter] = filter
        end

        signal_connect("selection_changed") do
          import_button.sensitive = filename && File.file?(filename)
        end

        # before adding the (hidden) progress bar, we must re-set the
        # packing of the button box (currently packed at the end),
        # because the progressbar will be *after* the button box.
        buttonbox = child.children.last
        child.set_child_packing(buttonbox, pack_type: :start)
        child.reorder_child(buttonbox, 1)

        pbar = Gtk::ProgressBar.new
        pbar.show_text = true
        child.pack_start(pbar, expand: false)
      end

      def acquire
        on_progress = proc do |fraction|
          pbar.show unless pbar.visible?
          pbar.fraction = fraction
        end

        on_error = proc do |message|
          SkipEntryDialog.new(self, message).continue?
        end

        exec_queue = ExecutionQueue.new

        while !@destroyed &&
            ((response = run) != Gtk::ResponseType::CANCEL) &&
            response != Gtk::ResponseType::DELETE_EVENT

          if response == Gtk::ResponseType::HELP
            Alexandria::UI.display_help(self, "import-library")
            next
          end
          file = File.basename(filename, ".*")
          base = GLib.locale_to_utf8(file)
          new_library_name = Library.generate_new_name(
            LibraryCollection.instance.all_libraries,
            base)

          filter = filters[self.filter]
          puts "Going forward with filter: #{filter.name}" if $DEBUG
          self.sensitive = false

          filter.on_iterate do |n, total|
            unless @destroyed
              fraction = n * 1.0 / total
              puts "#{inspect} fraction: #{fraction}" if $DEBUG
              exec_queue.call(on_progress, fraction)
            end
          end

          not_cancelled = true
          filter.on_error do |message|
            not_cancelled = exec_queue.sync_call(on_error, message)
            puts "#{inspect} cancel state: #{not_cancelled}" if $DEBUG
          end

          library = nil
          @bad_isbns = nil
          @failed_isbns = nil
          thread = Thread.start do
            begin
              library, @bad_isbns, @failed_isbns = filter.invoke(new_library_name,
                                                                 filename)
            rescue StandardError => ex
              trace = ex.backtrace.join("\n> ")
              log.error { "Import failed: #{ex.message} #{trace}" }
            end
          end

          while thread.alive? && !@destroyed
            # puts "Thread #{thread} still alive."
            @running = true
            exec_queue.iterate
            Gtk.main_iteration_do(false)
          end

          unless @destroyed
            if library
              yield(library, @bad_isbns, @failed_isbns)
              break
            elsif not_cancelled
              puts "Raising ErrorDialog because not_cancelled is #{not_cancelled}" if $DEBUG
              ErrorDialog.new(self,
                              _("Couldn't import the library"),
                              _("The format of the file you " \
                                "provided is unknown.  Please " \
                                "retry with another file.")).display
            end
            pbar.hide
            self.sensitive = true
          end
        end
        destroy unless @destroyed
      end
    end
  end
end
