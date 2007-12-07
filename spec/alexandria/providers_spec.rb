require File.dirname(__FILE__) + '/../spec_helper'

def __test_provider(provider, query, search_type = Alexandria::BookProviders::SEARCH_BY_ISBN)
    results = nil
    
    Proc.new do 
      results = provider.instance.search(query, search_type)
    end.should_not raise_error("Something wrong here.")
    puts results.inspect if $DEBUG
    results.class.should == Array # "Results are not an array")
    results.should_not be_empty #, "Results are empty")
    if search_type == Alexandria::BookProviders::SEARCH_BY_ISBN
    	results.length.should <= 2 #, "Results are greater than 2")
    	if results.length == 2
    	    results.last.class.should == String # "Result is not a String")
    	end
    	results.first.isbn.should == query #, "Result's isbn #{results.first.isbn} is not the same as requested isbn #{query}")
    	results.first.class.should == Alexandria::Book #, "Result is not a Book")
    	results.first
    	else
    		  results.first.first.class.should == Alexandria::Book #, "Result item is not a Book")
    end   
end

describe Alexandria do
  it "should not piss off Rich Burridge" do
    __test_provider(Alexandria::BookProviders::AmazonProvider,
                        '033025068X')
  end
  
    it "amazon should work" do
        __test_provider(Alexandria::BookProviders::AmazonProvider,
                        '9780385504201')
    end
    
    it "amazon title should work" do
    	__test_provider(Alexandria::BookProviders::AmazonProvider,
                        'A Confederacy of Dunces', Alexandria::BookProviders::SEARCH_BY_TITLE)
    end
    
    it "amazon authors should work" do
    	__test_provider(Alexandria::BookProviders::AmazonProvider,
                        'John Kennedy Toole', Alexandria::BookProviders::SEARCH_BY_AUTHORS)
    end
    
    it "amazon keyword should work" do
    	__test_provider(Alexandria::BookProviders::AmazonProvider,
                        'Confederacy Dunces', Alexandria::BookProviders::SEARCH_BY_KEYWORD)
    end
    
    it "dea should work" do
        __test_provider(Alexandria::BookProviders::DeaStore_itProvider,
                        '9788817012980') 
        __test_provider(Alexandria::BookProviders::DeaStore_itProvider,
                        '9788806134747') 
    end

    # Right? Don't test if dependency isn't present. 

#    def test_LOC
#      begin
#        require 'zoom'
#      rescue LoadError
#        return true
#      end
#      __test_provider(Alexandria::BookProviders::LOCProvider,
#                        '9780805335583')
#      # this book has non-ASCII letters
#      __test_provider(Alexandria::BookProviders::LOCProvider,
#                        '9782070379248')
#    end

#    def test_BL
#      begin
#        require 'zoom'
#      rescue LoadError
#        return true
#      end

#        __test_provider(Alexandria::BookProviders::BLProvider,
#                        '9781853260803')
#    end

#    def test_SBN
#      begin
#        require 'zoom'
#      rescue LoadError
#        return true
#      end

#      __test_provider(Alexandria::BookProviders::SBNProvider,
#                        '9788835926436')
#    end

    # providers supposed to be always working

    it "bn should work" do
        __test_provider(Alexandria::BookProviders::BNProvider,
                         '9780961328917')   # see #1433  
    end

    it "MCU should work" do
        # this book is without binding information, see bug [#2533]
        __test_provider(Alexandria::BookProviders::MCUProvider,
                        '9788487982033') 
        # this book is "agotado" (out of print), see bug [#2518]
        __test_provider(Alexandria::BookProviders::MCUProvider,
                        '9788496075856') 
    end

    it "Proxis should work" do
        __test_provider(Alexandria::BookProviders::ProxisProvider,
                        '9789026965746')
        __test_provider(Alexandria::BookProviders::ProxisProvider,
			'9780586071403')
    end

    it "Thalia should work" do
        # german book
        __test_provider(Alexandria::BookProviders::ThaliaProvider,
                        '9783896673305') 
        # international book
        __test_provider(Alexandria::BookProviders::ThaliaProvider,
                        '9780440241904')
        # movie dvd
        __test_provider(Alexandria::BookProviders::ThaliaProvider,
                        '4010232037824')
        # music cd
        __test_provider(Alexandria::BookProviders::ThaliaProvider,
                        '0094638203520')
    end

    it "IBS_it should work" do
        # this tests a book without image but with author
        __test_provider(Alexandria::BookProviders::IBS_itProvider,
                        '9788886973816') 
        # this tests a book with image but without author
        __test_provider(Alexandria::BookProviders::IBS_itProvider,
                        '9788807710148') 
    end
    
    it "AdLibris should work" do
        __test_provider(Alexandria::BookProviders::AdlibrisProvider,
                        '9789100109332') 
    end
     
    it "Siciliano should work" do
        __test_provider(Alexandria::BookProviders::SicilianoProvider,
                        '9788599170380') 
    end

    it "BOL_it should work" do
        __test_provider(Alexandria::BookProviders::BOL_itProvider,
                        '9788817012980') 
    end

    it "Webster should work" do
        # BIT
        __test_provider(Alexandria::BookProviders::Webster_itProvider,
                        '9788817012980') 
        # BUK
        __test_provider(Alexandria::BookProviders::Webster_itProvider,
                        '9781853260803') 
        # BUS
        __test_provider(Alexandria::BookProviders::Webster_itProvider,
                        '9780307237699') 
        # BDE
        __test_provider(Alexandria::BookProviders::Webster_itProvider,
                        '9783442460878') 
    end
    
    it "Webster should work with multiple authors" do
    	this_book = __test_provider(Alexandria::BookProviders::Webster_itProvider,
                        '9788804559016')
        assert_kind_of(Array, this_book.authors, "Not an array!")
        #puts this_book.authors
        assert(this_book.authors.length == 3, "Wrong number of authors for this book!")
    end

    it "Renaud should work" do
        # adultes 
        __test_provider(Alexandria::BookProviders::RENAUDProvider,
                        '9782894723388')
        # jeunesse
        __test_provider(Alexandria::BookProviders::RENAUDProvider,
                        '9782764605059')
    end

    it "Worldcat should work" do
        __test_provider(Alexandria::BookProviders::WorldcatProvider,
                        '9780521247108') 
        # this one is with <div class=vernacular lang="[^"]+">)
        __test_provider(Alexandria::BookProviders::WorldcatProvider,
                        '9785941454136') 
    end
    
    it "Worldcat should work with multiple authors" do
		this_book = __test_provider(Alexandria::BookProviders::WorldcatProvider,
                        '9785941454136')
        assert_kind_of(Array, this_book.authors, "Not an array!")
        #puts this_book.authors
        assert(this_book.authors.length == 2, "Wrong number of authors for this book!")
	
	end
end
