# -*- ruby -*-

$:.unshift(File.join(File.dirname(__FILE__), '../../lib'))

require  'alexandria'

LIBDIR = File.expand_path(File.join(File.dirname(__FILE__), '../data/libraries'))
TESTDIR = File.join(LIBDIR, 'test')


def useTestLibrary(version)
  FileUtils.rm_rf(TESTDIR)
  libVersion = File.join(LIBDIR, version)
  FileUtils.cp_r(libVersion, TESTDIR)
end

# find a nicer way to do this... it generates a warning at the moment
module Alexandria
  class Library
    DIR = TESTDIR
  end
end

describe "Library class" do

  it "has symbolic references to file extensions" do
    extensions = Alexandria::Library::EXT
    extensions[:book].should_not be_nil
    extensions[:cover].should_not be_nil
  end

  it "imports cleanly from version 0.6.1 data format" do
    #libraryDataVersion '0.6.1'
    puts "[#{Alexandria::Library::DIR}]"
    useTestLibrary '0.6.1'
    libs = Alexandria::Library.loadall
    libs.size.should == 1
    myLibrary = libs[0]
    myLibrary.size.should == 3
    # Malory
    maloryBook = myLibrary.select {|b| b.isbn == '9780192812179'}[0]
    maloryBook.publisher.should == 'Oxford University Press'
    maloryBook.authors.include?('Vinaver').should be_true
    maloryBook.version.should == Alexandria::VERSION
    
    # Guide to LaTeX
    latexBook = myLibrary.select{|b| b.title.include? 'Latex'}[0]
    latexBook.isbn.should == '9780201398250'
    latexBook.publisher.should == 'Addison Wesley' # note, no Ruby-Amazon cruft
  end

end
