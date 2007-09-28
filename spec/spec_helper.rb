$:.unshift(File.join(File.dirname(__FILE__), '/../lib'))

require  'alexandria'

LIBDIR = File.expand_path(File.join(File.dirname(__FILE__), '/data/libraries'))
TESTDIR = File.join(LIBDIR, 'test')


#def useTestLibrary(version)
#  libVersion = File.join(LIBDIR, version)
#  FileUtils.cp_r(libVersion, TESTDIR)
#end

def an_artist_of_the_floating_world
  Alexandria::Book.new("An Artist of the Floating World",
                       "Kazuo Ishiguro",
                       "9780571147168",
                       "Faber and Faber", 1999,
                       "Paperback")
end


# find a nicer way to do this... it generates a warning at the moment
module Alexandria
  class Library
    DIR = TESTDIR
  end
end

