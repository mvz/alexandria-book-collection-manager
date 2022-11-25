# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

RSpec.describe Alexandria::BookProviders::WorldCatProvider do
  let(:sky_catalog_main) do
    <<~XHTML
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en" dir="ltr">
        <head></head>
        <body id="worldcat">
          <table class="table-results">
            <tr class="menuElem">
              <td class="result details">
                <div class="name">
                  <a id="result-1" href="/title/sky-catalogue-20000-ed-by-alan-hirshfeld-and-roger-w-sinnott/oclc/476534140&referer=brief_results"><strong>Sky catalogue 2000.0 ed. by Alan Hirshfeld and Roger W. Sinnott</strong></a>
                </div>
                <div class="type">
                  <img class='icn' src='https://static1.worldcat.org/wcpa/rel20201014/images/icon-bks.gif' alt=' ' height='16' width='16' />&nbsp;<span class='itemType'>Print book</span>
                </div>
              </td>
            </tr>
            <tr class="menuElem">
              <td class="result details">
                <div class="name">
                  <a id="result-2" href="/title/sky-catalogue-20000/oclc/7978015&referer=brief_results"><strong>Sky catalogue 2000.0</strong></a>
                </div>
                <div class="type">
                  <img class='icn' src='https://static1.worldcat.org/wcpa/rel20201014/images/icon-bks.gif' alt=' ' height='16' width='16' />&nbsp;<span class='itemType'>Print book</span>
                </div>
              </td>
            </tr>
          </table>
        </body>
      </html>
    XHTML
  end

  let(:sky_catalog_details) do
    <<~XHTML
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en" dir="ltr">
        <head></head>
        <body id="worldcat">
          <div id="bibdata">
            <h1 class="title">Sky catalogue 2000.0 ed. by Alan Hirshfeld and Roger W. Sinnott</h1>
            <table border="0" cellspacing="0" cellpadding="0">
              <tr id="bib-author-row">
                <th>Author:</th>
                <td id="bib-author-cell">
                  <a href='/search?q=au%3AHirshfeld+Alan&amp;qt=hot_author' title='Search for more by this author'>Hirshfeld Alan</a>;
                  <a href='/search?q=au%3ASinnott+Roger+W.&amp;qt=hot_author' title='Search for more by this author'>Sinnott Roger W.</a>;
                  <a href='/search?q=au%3ACambridge+Cambridge+University+Press+1982-&amp;qt=hot_author' title='Search for more by this author'>Cambridge Cambridge University Press 1982-</a>
                </td>
              </tr>
              <tr id="bib-publisher-row">
                <th>Publisher:</th>
                <td id="bib-publisher-cell">1982</td>
              </tr>
            </table>
          </div>
          <table border="0" cellspacing="0">
            <tr id="details-allauthors">
              <th>All Authors / Contributors:</th>
              <td>
                <a href='/search?q=au%3AHirshfeld+Alan&amp;qt=hot_author' title='Search for more by this author'>Hirshfeld Alan</a>;
                <a href='/search?q=au%3ASinnott+Roger+W.&amp;qt=hot_author' title='Search for more by this author'>Sinnott Roger W.</a>;
                <a href='/search?q=au%3ACambridge+Cambridge+University+Press+1982-&amp;qt=hot_author' title='Search for more by this author'>Cambridge Cambridge University Press 1982-</a>
              </td>
            </tr>
            <tr id="details-standardno">
              <th>ISBN:</th>
              <td>0521247101 9780521247108 0521289130 9780521289139 0521258189 9780521258180</td>
            </tr>
          </table>
        </body>
      </html>
    XHTML
  end

  let(:florence_ru_details) do
    <<~XHTML
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en" dir="ltr">
        <head></head>
        <body id="worldcat">
          <div id="bibdata">
            <h1 class="title">
              <div class="vernacular" lang="ru">Флоренс Аравийская : роман /</div>
              Florens Araviĭskai︠a︡ : roman
            </h1>
            <table border="0" cellspacing="0" cellpadding="0">
              <tr id="bib-author-row">
                <th>Author:</th>
                <td id="bib-author-cell">
                  <span class="vernacular" lang="ru">Кристофер Бакли ; перевод с английского Андрея Геласимова.</span>
                  <span class="vernacular" lang="ru">Геласимов, Андрей.</span> ;
                  <a href="/search?q=au%3ABuckley%2C+Christopher%2C&amp;qt=hot_author" title="Search for more by this author">Christopher Buckley</a>;
                  <a href="/search?q=au%3AGelasimov%2C+Andrei%CC%86.&amp;qt=hot_author" title="Search for more by this author">Andreĭ Gelasimov</a>
                </td>
              </tr>
              <tr id="bib-publisher-row">
                <th>Publisher:</th>
                <td id="bib-publisher-cell"><span class="vernacular" lang="ru">Иностранка,</span>
                  Moskva : Inostranka, 2006.
                </td>
              </tr>
            </table>
          </div>
          <table border="0" cellspacing="0">
            <tr id="details-allauthors">
              <th>All Authors / Contributors:</th>
              <td>
                <span class="vernacular" lang="ru">Кристофер Бакли ; перевод с английского Андрея Геласимова.</span>
                <span class="vernacular" lang="ru">Геласимов, Андрей.</span> ;
                <a href="/search?q=au%3ABuckley%2C+Christopher%2C&amp;qt=hot_author" title="Search for more by this author">Christopher Buckley</a>;
                <a href="/search?q=au%3AGelasimov%2C+Andrei%CC%86.&amp;qt=hot_author" title="Search for more by this author">Andreĭ Gelasimov</a>
              </td>
            </tr>
            <tr id="details-standardno">
              <th>ISBN:</th>
              <td>5941454139 9785941454136</td>
            </tr>
          </table>
        </body>
      </html>
    XHTML
  end

  it "works for an isbn with multiple results" do
    stub_request(:get, "https://www.worldcat.org/search?q=isbn:9780521247108&qt=advanced")
      .to_return(status: 200, body: +sky_catalog_main, headers: {})
    stub_request(:get,
                 "https://www.worldcat.org/title/" \
                 "sky-catalogue-20000-ed-by-alan-hirshfeld-and-roger-w-sinnott" \
                 "/oclc/476534140&referer=brief_results")
      .to_return(status: 200, body: +sky_catalog_details, headers: {})
    expect(described_class).to have_correct_search_result_for "9780521247108"
  end

  it "works with vernacular" do
    stub_request(:get, "https://www.worldcat.org/search?q=isbn:9785941454136&qt=advanced")
      .to_return(status: 200, body: +florence_ru_details, headers: {})
    expect(described_class).to have_correct_search_result_for "9785941454136"
  end

  context "when book has multiple authors" do
    let(:search_result) do
      described_class.instance.search("9785941454136",
                                      Alexandria::BookProviders::SEARCH_BY_ISBN)
    rescue SocketError
      skip "Service is offline"
    end

    before do
      stub_request(:get, "https://www.worldcat.org/search?q=isbn:9785941454136&qt=advanced")
        .to_return(status: 200, body: +florence_ru_details, headers: {})
    end

    it "returns all authors" do
      this_book, = search_result
      aggregate_failures do
        expect(this_book.authors).to be_instance_of(Array), "Not an array!"
        expect(this_book.authors.length).to eq(2), "Wrong number of authors for this book!"
      end
    end
  end

  describe "#url" do
    it "returns an url with isbn" do
      book = an_artist_of_the_floating_world
      url = described_class.instance.url(book)
      expect(url).to eq "https://www.worldcat.org/search?q=isbn%3A9780571147168&qt=advanced"
    end
  end
end
