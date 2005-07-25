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

require 'osx/cocoa'
require 'osx/objc/oc_all'

begin
    require 'gettext'
rescue LoadError
    module GetText
        module_function
        def _(str)
            str
        end
        def n_(str1, str2, n)
            n > 1 ? str2 : str1
        end
        def bindtextdomain(domainname, path = nil, locale = nil, charset = nil)
        end
    end
end

$MACOSX = true

require 'alexandria'

def rb_main_init
    path = OSX::NSBundle.mainBundle.resourcePath.fileSystemRepresentation
    rbfiles = Dir.entries(path).select {|x| /\.rb\z/ =~ x}
    rbfiles -= [ File.basename(__FILE__) ]
    rbfiles.each do |path|
        require(File.basename(path))
    end
end

if $0 == __FILE__ then
    rb_main_init
    #$DEBUG = true
    Thread.abort_on_exception = true
    Alexandria::UI.main
end