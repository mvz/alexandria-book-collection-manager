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
    class ExportController < OSX::NSObject
        include OSX

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        ib_outlets :accessoryView, :formatsPopupButton, :mainWindow,
                   :themesPopupButton, :themesLabel, :previewImageView
        
        def awakeFromNib
            @formatsPopupButton.removeAllItems
            ExportFormat.all.each do |exportFormat|
                @formatsPopupButton.addItemWithTitle(exportFormat.name)
            end

            @formatsPopupButton.setTarget(self)
            @formatsPopupButton.setAction('_formatsDidChange:')
            @formatsPopupButton.selectItemAtIndex(0)
            
            @themesPopupButton.removeAllItems
            WebTheme.all.each do |webTheme|
                @themesPopupButton.addItemWithTitle(webTheme.name)
            end

            @themesPopupButton.selectItemAtIndex(0)
        end
        
        def openWindow(selectedLibrary)
            @selectedLibrary = selectedLibrary
            directory = OSX::NSHomeDirectory()

            @panel = NSSavePanel.savePanel
            @panel.setPrompt(_('Export'))
            @panel.setNameFieldLabel(_('Export As:'))
            @panel.setAccessoryView(@accessoryView)
            _formatsDidChange(nil)  # force type file setup
            @panel.beginSheetForDirectory(directory, :file, selectedLibrary.name,
                                                     :modalForWindow, @mainWindow,
                                                     :modalDelegate, self,
                                                     :didEndSelector, '_savePanelDidEnd:returnCode:contextInfo:',
                                                     :contextInfo, nil)
        end
        
        def _selectedExportFormat
            pos = @formatsPopupButton.indexOfSelectedItem
            ExportFormat.all[pos]
        end

        def _selectedWebTheme
            pos = @themesPopupButton.indexOfSelectedItem
            WebTheme.all[pos]
        end

        def _formatsDidChange(sender)
            exportFormat = _selectedExportFormat
            @panel.setRequiredFileType(exportFormat.ext)

            if exportFormat.needs_preview?
                @themesPopupButton.setEnabled(true)
            else
                @themesPopupButton.setEnabled(false)
            end
        end
        
        def _savePanelDidEnd_returnCode_contextInfo(sheet, returnCode, contextInfo)
            return unless returnCode == NSOKButton
            
            exportFormat = _selectedExportFormat
            additionalArgs = []
            if exportFormat.needs_preview?
                additionalArgs << _selectedWebTheme
            end
            
            exportFormat.invoke(@selectedLibrary,
                                sheet.filename.to_s,
                                *additionalArgs)
        end
    end
end
end