# Copyright (C) 2004-2006 Laurent Sansonetti
# Copyright (C) 2011, 2016 Matijs van Zuijlen
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

require 'thread'

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
    class SkipEntryDialog < AlertDialog
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: 'UTF-8')

      def initialize(parent, message)
        super(parent, _('Error while importing'),
              Gtk::Stock::DIALOG_QUESTION,
              [[Gtk::Stock::CANCEL, :cancel],
               [_('_Continue'), :ok]],
              message)
        puts "Opened SkipEntryDialog #{inspect}" if $DEBUG
        self.default_response = Gtk::ResponseType::CANCEL
        show_all && (@response = run)
        destroy
      end

      def continue?
        @response == :ok
      end
    end

    class ImportDialog < Gtk::FileChooserDialog
      include GetText
      include Logging

      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, charset: 'UTF-8')

      FILTERS = Alexandria::ImportFilter.all

      def initialize(parent)
        super()
        puts 'ImportDialog opened.' if $DEBUG
        @destroyed = false
        self.title = _('Import a Library')
        self.action = :open
        self.transient_for = parent
        #            self.deletable = false
        running = false
        add_button(Gtk::Stock::HELP, :help)
        add_button(Gtk::Stock::CANCEL, :cancel)
        import_button = add_button(_('_Import'),
                                   :accept)
        import_button.sensitive = false

        signal_connect('destroy') {
          if running
            @destroyed = true

          else
            destroy
          end
          # self.destroy unless running
        }

        filters = {}
        FILTERS.each do |filter|
          filefilter = filter.to_filefilter
          add_filter(filefilter)
          puts "Added ImportFilter #{filefilter} -- #{filefilter.name}" if $DEBUG
          filters[filefilter] = filter
        end

        signal_connect('selection_changed') do
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

        on_progress = proc do |fraction|
          begin
            pbar.show unless pbar.visible?
            pbar.fraction = fraction
          rescue
            # TODO: check if destroyed instead...
          end
        end

        on_error = proc do |message|
          SkipEntryDialog.new(parent, message).continue?
        end

        exec_queue = ExecutionQueue.new

        while !@destroyed &&
            ((response = run) != :cancel) &&
            (response != :delete_event)

          if response == :help
            Alexandria::UI.display_help(self, 'import-library')
            next
          end
          file = File.basename(filename, '.*')
          base = GLib.locale_to_utf8(file)
          new_library_name = Library.generate_new_name(
            Libraries.instance.all_libraries,
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
            rescue => ex
              trace = ex.backtrace.join("\n> ")
              log.error { "Import failed: #{ex.message} #{trace}" }
            end
          end

          while thread.alive? && !@destroyed
            # puts "Thread #{thread} still alive."
            running = true
            exec_queue.iterate
            Gtk.main_iteration_do(false)
          end

          unless @destroyed
            if library
              yield(library, @bad_isbns, @failed_isbns)
              break
            elsif not_cancelled
              puts "Raising ErrorDialog because not_cancelled is #{not_cancelled}" if $DEBUG
              ErrorDialog.new(parent,
                              _("Couldn't import the library"),
                              _('The format of the file you ' \
                                'provided is unknown.  Please ' \
                                'retry with another file.'))
            end
            pbar.hide
            self.sensitive = true
          end
        end
        unless @destroyed
          destroy
        end
      end
    end
  end
end
