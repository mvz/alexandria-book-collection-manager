# Copyright (C) 2005 Laurent Sansonetti
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
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

module Alexandria
module UI
    class ImportPanel < OSX::NSOpenPanel
        include OSX

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        ns_overrides 'ok:'
        
        attr_reader :library

        RESPONSE_DONE, RESPONSE_CANCEL = 1, 2

        def progressSheetDidEnd_returnCode_contextInfo(sheet, returnCode, contextInfo)
            sheet.orderOut(self)
            if @library != nil and !@library.empty?
                super_ok(self)
            else
                _alert(_("The format of the file you " +
                         "provided is unknown.  Please " +
                         "retry with another file."))
            end
        end

        def ok(sender)
            delegate = self.delegate

            libraryName = delegate.proposedLibraryName
            if delegate.librariesDataSource.libraries.find { |x| x.name == libraryName } != nil
                _alert(_("There is already a library named " +
                         "'%s'.  Please choose a different " +
                         "name.") % libraryName)
                return
            end
            
            importFilter = delegate.selectedImportFilter
            filename = delegate.selectedFilename
            progressWindow = delegate.progressWindow
            importProgressIndicator = delegate.importProgressIndicator
            
            app = NSApplication.sharedApplication
            app.beginSheet(progressWindow, :modalForWindow, self,
                                           :modalDelegate, self,
                                           :didEndSelector, 'progressSheetDidEnd:returnCode:contextInfo:',
                                           :contextInfo, nil)

            queue = ExecutionQueue.new
            
            importProgressIndicator.setIndeterminate(true)
            importProgressIndicator.startAnimation(self)
    
            on_progress = proc do |fraction|
                if importProgressIndicator.isIndeterminate?
                    importProgressIndicator.stopAnimation(self)
                    importProgressIndicator.setIndeterminate(false)
                end
                importProgressIndicator.setDoubleValue(fraction)
            end

            on_error = proc do |message|
                p 'error: ' + message
                true
            end

            on_finished = proc do
                NSApplication.sharedApplication.endSheet_returnCode(progressWindow, 
                                                                    RESPONSE_DONE)
            end

            importFilter.on_iterate do |n, total|
                # convert to percents
                coeff = total / 100.0
                percent = n / coeff
                queue.call(on_progress, percent)
            end

            not_cancelled = true
            importFilter.on_error do |message|
                not_cancelled = queue.sync_call(on_error, message)
            end

            @library = nil
            GC.start
            thread = Thread.start do
                begin
                    @library = importFilter.invoke(libraryName, filename)
                rescue => e
                    # we should not be there anyway...
                    p e.message
                ensure
                    queue.sync_call(on_finished)
                end
            end

            while thread.alive?
                queue.iterate
                NSRunLoop.currentRunLoop.runUntilDate(NSDate.distantPast)
            end            
            queue.stop
        end
        
        def stop(sender)
            # TODO: the stop button is not there at the moment...
            #NSApplication.sharedApplication.endSheet_returnCode(@progressWindow, 
            #                                                    RESPONSE_CANCEL)
        end
        
        #######
        private
        #######
        
        def _alert(description)
            alert = NSAlert.alloc.init
            alert.setMessageText(_("Couldn't import the library"))
            alert.setInformativeText(description)
            alert.addButtonWithTitle(_("OK"))

            alert.beginSheetModalForWindow(self, :modalDelegate, nil,
                                                 :didEndSelector, nil,
                                                 :contextInfo, nil)
        end
    end

    class ImportController < OSX::NSObject
        include OSX

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        ib_outlets :mainWindow, :accessoryView, :formatsPopupButton,
                   :libraryTextField, :progressWindow, :importProgressIndicator,
                   :librariesDataSource

        attr_reader :progressWindow, :importProgressIndicator, :librariesDataSource

        def awakeFromNib
            @formatsPopupButton.removeAllItems
            ImportFilter.all.each do |importFilter|
                @formatsPopupButton.addItemWithTitle(importFilter.name)
            end

            @formatsPopupButton.setTarget(self)
            @formatsPopupButton.setAction('_formatsDidChange:')
            @formatsPopupButton.selectItemAtIndex(0)
        end

        def openWindow(&finish_block)
            @finish_block = finish_block
            directory = OSX::NSHomeDirectory()

            @panel = ImportPanel.openPanel
            @panel.setCanChooseFiles(true)
            @panel.setCanChooseDirectories(false)
            @panel.setResolvesAliases(true)
            @panel.setPrompt(_('Import'))
            @panel.setAccessoryView(@accessoryView)
            @panel.setDelegate(self)
            
            _formatsDidChange(nil)  # force type file setup

            @panel.beginSheetForDirectory(directory, :file, nil,
                                                     :types, nil,
                                                     :modalForWindow, @mainWindow,
                                                     :modalDelegate, self,
                                                     :didEndSelector, '_openPanelDidEnd:returnCode:contextInfo:',
                                                     :contextInfo, nil)
        end

        def selectedImportFilter
            pos = @formatsPopupButton.indexOfSelectedItem
            ImportFilter.all[pos]
        end

        def selectedFilename
            filenames = @panel.filenames
            filenames.count > 0 ? filenames.objectAtIndex(0).to_s : nil
        end
        
        def proposedLibraryName
            @libraryTextField.stringValue.to_s.strip
        end

        def _openPanelDidEnd_returnCode_contextInfo(sheet, returnCode, contextInfo)
            if returnCode == NSOKButton
                @finish_block.call(@panel.library)
            end
        end
        
        def stop(sender)
            @panel.stop(sender)
        end
        
        def _formatsDidChange(sender)
            #importFilter = selectedImportFilter
            #patterns = importFilter.patterns.map do |x| 
            #    x == '*' ? nil : x.delete('*.')
            #end
            #@panel._setEnabledFileTypes(patterns.include?(nil) ? nil : patterns)
        end

        def panel_userEnteredFilename_confirmed(panel, filename, confirmed)
            p filename, confirmed
            return filename unless confirmed
           
            return filename 
        end

        def panelSelectionDidChange(sender)
            filename = selectedFilename
            @libraryTextField.setStringValue(filename != nil ? File.basename(filename, '.*') : "")
        end
    end
end
end