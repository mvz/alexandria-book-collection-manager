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
    class AboutController < OSX::NSObject
        include OSX

        include GetText
        GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")

        ib_outlets :copyrightTextField, :versionTextField, :detailsTextView,
                   :window, :descriptionTextField

        def awakeFromNib
            @copyrightTextField.setStringValue(Alexandria::COPYRIGHT)
            @descriptionTextField.setStringValue(Alexandria::DESCRIPTION)
            @versionTextField.setStringValue(Alexandria::VERSION)
                        
            detailsAttString = @detailsTextView.textStorage            
            #@detailsTextView.setTextContainerInset(OSX::NSSize.new(10, 10))
            @detailsTextView.updateRuler

            titleAttributes = NSMutableDictionary.dictionary
            titleAttributes.setObject_forKey(NSFont.fontWithName_size("Lucida Grande Bold", 10), 
                                             "NSFont")
            contentAttributes = NSMutableDictionary.dictionary
            contentAttributes.setObject_forKey(NSFont.fontWithName_size("Lucida Grande", 10), 
                                               "NSFont")

            append = proc do |string, attributes|
                attString = if attributes
                    NSAttributedString.alloc.initWithString_attributes(string,
                                                                       attributes)
                else
                    NSAttributedString.alloc.initWithString(string)
                end
                detailsAttString.appendAttributedString(attString)
            end

            [[Alexandria::AUTHORS, "Contributors"],
             [Alexandria::ARTISTS, "Artists"],
             [Alexandria::DOCUMENTERS, "Documenters"],
             [Alexandria::TRANSLATORS, "Translators"]].each do |content, title|

                append.call(title, titleAttributes)
                content.each do |people| 
                    append.call("\n\t", nil)
                    next unless md = /^(.+)\s*\<(.+)\>.*$/.match(people)
                    name, email = md[1], md[2]
                    mailto = NSURL.URLWithString("mailto:" + email)
                    contentAttributes.setObject_forKey(mailto, "NSLink")
                    contentAttributes.setObject_forKey(NSCursor.pointingHandCursor, "NSCursor")
                    append.call(name, contentAttributes)
                    contentAttributes.removeObjectForKey("NSLink")
                    contentAttributes.removeObjectForKey("NSCursor")
                end
                append.call("\n\n", nil)
            end
            append.call("... and thanks to all users!", contentAttributes)
        end
    
        def openWindow
            @window.makeKeyAndOrderFront(self)
            @running = true
        end
        
        def opened?
            @running
        end
        
        # NSWindow delegation
        
        def windowWillClose(notification)
            @running = false
        end
    end
end
end