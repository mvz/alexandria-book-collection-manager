#-- -*- ruby -*-
# Copyright (C) 2007 Cathal Mc Ginley
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
require File.dirname(__FILE__) + '/../spec_helper'

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
    #puts "first_copy #{first_copy.object_id}"
    myLibrary << first_copy
    myLibrary.delete(first_copy)

    second_copy = an_artist_of_the_floating_world()
    myLibrary << second_copy
    third_copy = an_artist_of_the_floating_world()
    myLibrary << third_copy

    #puts "AAA myLibrary.size #{myLibrary.size}"

    #puts "second_copy #{second_copy.object_id}"
    #lambda {  myLibrary.delete(second_copy) }.should raise_error
    lambda { myLibrary.delete(second_copy) }.should_not raise_error


    #puts "BBB myLibrary.size #{myLibrary.size}"
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

describe Alexandria::Library, " with books without an ISBN" do

  before(:each) do
    libVersion = File.join(LIBDIR, '0.6.1-noisbn')
    FileUtils.cp_r(libVersion, TESTDIR)
  end


  it "allows books to have no ISBN" do
      libs = Alexandria::Library.loadall
      libs.size.should == 1
      myLibrary = libs[0]
      myLibrary.size.should == 2

      # Guide to LaTeX
      latexBook = myLibrary.select{|b| b.title.include? 'Latex'}[0]
      latexBook.isbn.should == '9780201398250'
      latexBook.publisher.should == 'Addison Wesley' # note, no Ruby-Amazon cruft
      latexBook.version.should == Alexandria::VERSION

      #Lex and Yacc
      lexAndYaccBook = myLibrary.select{|b| b.title.include? 'Lex'}[0]
      lexAndYaccBook.publisher.should == "O'Reilley"

      #puts "ident -> " + lexAndYaccBook.ident

      myLibrary.each do |book|
          myLibrary.save(book, true)
      end
      libs = nil
      myLibrary = nil

      librariesReloaded = Alexandria::Library.loadall
      myLibraryReloaded = librariesReloaded[0]

      myLibraryReloaded.size.should == 2

      latexBook = myLibraryReloaded.select{|b| b.title.include? 'Latex'}[0]
      latexBook.should_not be_nil
      latexBook.publisher.should == 'Addison Wesley'
      #puts latexBook.title

      lexAndYaccBook = myLibraryReloaded.select{|b| b.title.include? 'Lex'}[0]
      lexAndYaccBook.should_not be_nil
      lexAndYaccBook.publisher.should == "O'Reilley"
      #puts lexAndYaccBook.title

  end

  after(:each) do
      FileUtils.rm_rf(TESTDIR)
  end

end

