# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

require "spec_helper"

RSpec.describe Alexandria::BookProviders::ThaliaProvider do
  let(:normal_people_main) do
    +<<~HTML
      <!DOCTYPE html>
      <html lang="de" data-environment="prod">
        <head>
          <title>Artikel von 0571334652 ansehen | Thalia</title>
        </head>
        <body data-mandant="2" data-version="20201112100740_528b0df" data-environment="prod">
          <main class="suche-grid--main nur-suchergebnis">
            <section class="suchergebnis">
              <ul class="suchergebnis-liste no-bullets">
                <li class="suchergebnis" data-seite="1"
                                         data-ean="9780571334650"
                                         data-id="134292338"
                                         data-preis="9.49"
                                         data-preis-reduziert="false"
                                         data-alterpreis="">
                  <a href="/shop/home/artikeldetails/ID134292338.html" class="layered-link">Normal People von Sally Rooney</a>

                  <ul class="weitere-formate no-bullets" impression="product-variant">
                    <li class="format aktiv">
                      <a href="/shop/home/artikeldetails/ID134292338.html">Buch (Taschenbuch)</a>
                    </li>
                    <li class="format">
                      <a href="/shop/home/artikeldetails/ID95227195.html">Weitere: Buch (Taschenbuch)</a>
                    </li>
                  </ul>
                </li>
              </ul>
            </section>
          </main>
        </body>
      </html>
    HTML
  end
  let(:normal_people_details) do
    +<<~HTML
      <!DOCTYPE html>
      <html class="no-js" id="ID-2" lang="de">
        <head>
          <title>Normal People von Sally Rooney - Taschenbuch - 978-0-571-33465-0 | Thalia</title>
        </head>
        <body>
          <section class="artikel-medien imagesPreview">
            <img src="https://assets.thalia.media/img/artikel/ae9934c90f2c7d595146807ea6253c99532043ec-00-00.jpeg" class='largeImg'>
          </section>

          <section class="artikel-infos" id="sbe-product-details"
                                         data-shopid="2"
                                         data-id="A1051452169"
                                         data-id-alt="134292338"
                                         data-titel="Normal People"
                                         data-verfuegbarkeit="Sofort lieferbar"
                                         data-preis-netto="9.02"
                                         data-preis-brutto="9.49"
                                         data-ean="9780571334650"
                                         data-reduziert="false"
                                         data-waehrung="EUR"
                                         data-preis-liste="9.49"
                                         data-hersteller="Faber &amp; Faber"
                                         data-form="Taschenbuch"
                                         data-verkaufsrang="5"
                                         data-anzahlbewertungen="19"
                                         data-durchschnittsbewertung="4.5"
                                         data-preisbindung="false"
                                         data-mandant="2"
                                         data-environment="prod"
                                         component="artikeldetails-produktdetails">

            <h1 class="ncTitle">
              Normal People
            </h1>

            <p class="aim-author">
            <a href="https://www.thalia.de/shop/home/mehr-von-suche/ANY/sp/suche.html?mehrVon=Sally%20Rooney" interaction="autor-klick">Sally Rooney</a>
            </p>
          </section>

          <section class="artikeldetails">
            <table>
              <tr> <th> Einband </th> <td> Taschenbuch </td> </tr>
              <tr> <th> Erscheinungsdatum </th> <td> 02.05.2019 </td> </tr>
              <tr> <th> ISBN </th> <td> 978-0-571-33465-0 </td> </tr>
            </table>
            <table>
              <tr>
                <th> Verlag </th>
                <td>
                  <a href="https://www.thalia.de/shop/home/mehr-von-suche/ANY/sv/suche.html?mehrVon=Faber%20%26%20Faber" interaction="auswahl">
                    Faber &amp; Faber
                  </a>
                </td>
              </tr>
            </table>
          </section>
        </body>
      </html>
    HTML
  end

  it "works when searching by ISBN" do
    stub_request(:get,
                 "https://www.thalia.de/shop/bde_bu_hg_startseite/suche/?sq=0571334652")
      .to_return(status: 200, body: normal_people_main, headers: {})
    stub_request(:get, "https://www.thalia.de/shop/home/artikeldetails/ID134292338.html")
      .to_return(status: 200, body: normal_people_details, headers: {})

    assert_correct_search_result(described_class, "9780571334650")
  end
end
