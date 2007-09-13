# -*- ruby -*-

$:.unshift(File.join(File.dirname(__FILE__), '../../lib'))

require  'alexandria'

LIBDIR = File.expand_path(File.join(File.dirname(__FILE__), '../data/libraries'))
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

describe Alexandria::Library do

  before(:each) do
    FileUtils.mkdir(TESTDIR)
  end

  it "has symbolic references to file extensions" do
    extensions = Alexandria::Library::EXT
    extensions[:book].should_not be_nil
    extensions[:cover].should_not be_nil
  end

  it "disallows multiple deletion of the same copy of a book" do
    myLibrary = Alexandria::Library.loadall()[0]
    first_copy = an_artist_of_the_floating_world()
    myLibrary << first_copy
    myLibrary.delete(first_copy)
    lambda { myLibrary.delete(first_copy) }.should raise_error
  end

  it "allows multiple copies of a book to be added and deleted in turn" do
    myLibrary = Alexandria::Library.loadall()[0]
    first_copy = an_artist_of_the_floating_world()
    puts "first_copy #{first_copy.object_id}"
    myLibrary << first_copy
    myLibrary.delete(first_copy)

    second_copy = an_artist_of_the_floating_world()
    myLibrary << second_copy
    third_copy = an_artist_of_the_floating_world()
    myLibrary << third_copy

    puts "AAA myLibrary.size #{myLibrary.size}"

    puts "second_copy #{second_copy.object_id}"
    #lambda {  myLibrary.delete(second_copy) }.should raise_error
    lambda { myLibrary.delete(second_copy) }.should_not raise_error


    puts "BBB myLibrary.size #{myLibrary.size}"
    # myLibrary.size.should == 1 # not yet an established feature...
  end

  after(:each) do
    FileUtils.rm_rf(TESTDIR)
  end

end


describe Alexandria::Library, " imported from 0.6.1 data files" do

  before(:each) do
    libVersion = File.join(LIBDIR, '0.6.1')
    FileUtils.cp_r(libVersion, TESTDIR)
  end


  it "imports cleanly from version 0.6.1 data format" do
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

  after(:each) do
    FileUtils.rm_rf(TESTDIR)
  end

end
