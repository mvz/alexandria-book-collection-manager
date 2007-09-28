require File.dirname(__FILE__) + '/../spec_helper'

describe Alexandria::Book do
  it "should be a thing" do
    an_artist_of_the_floating_world
  end

  it "should establish equality only with books with the same identity" do
    (an_artist_of_the_floating_world == an_artist_of_the_floating_world).should be_true
    different_book = an_artist_of_the_floating_world
    different_book.isbn = "9780571147999"
    (an_artist_of_the_floating_world == different_book).should be_false
  end
end
