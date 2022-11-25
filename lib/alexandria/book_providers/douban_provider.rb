# frozen_string_literal: true

# This file is part of Alexandria.
#
# See the file README.md for authorship and licensing information.

# http://book.douban.com/
# Douban.com book repository, provides many Chinese books.

# Author: Sun Ning <classicning@gmail.com>, http://sunng.info/

require "cgi"
require "alexandria/net"
require "yaml"

module Alexandria
  class BookProviders
    class DoubanProvider < GenericProvider
      include Logging

      SITE = "http://www.douban.com"
      BASE_URL = "http://api.douban.com/book/subjects?q=%s&max-results=5&alt=json"

      def initialize
        super("Douban", "Douban (China)")
        prefs.read
      end

      def url(_book)
        nil
      end

      def search(criterion, type)
        keyword = criterion
        request_url = BASE_URL % CGI.escape(keyword)

        search_response = transport.get_response(URI.parse(request_url))

        results = parse_search_result(search_response.body)
        raise NoResultsError if results.empty?

        if type == SEARCH_BY_ISBN
          results.first
        else
          results
        end
      end

      private

      # The YAML parser in Ruby 1.8.6 chokes on the extremely
      # compressed inline-style of JSON returned by Douban. (Also, it
      # doesn't un-escape forward slashes).
      #
      # This is a quick-and-dirty method to pre-process the JSON into
      # YAML-parseable format, so that we don't have to drag in a new
      # dependency.
      def json2yaml(json)
        # insert spaces after : and , except within strings
        # i.e. when followed by numeral, quote, { or [
        yaml = json.gsub(/(:|,)([0-9'"{\[])/) do |_match|
          "#{Regexp.last_match[1]} #{Regexp.last_match[2]}"
        end
        yaml.gsub!(%r{\\/}, "/") # unescape forward slashes
        yaml
      end

      public

      def parse_search_result(response)
        book_search_results = []
        begin
          # dbresult = JSON.parse(response)
          dbresult = YAML.safe_load(json2yaml(response))
          # File.open(",douban.yaml", "wb") {|f| f.write(json2yaml(response)) }
          if dbresult["opensearch:totalResults"]["$t"].to_i > 0
            dbresult["entry"].each do |item|
              name = item["title"]["$t"]
              isbn = nil
              publisher = nil
              pubdate = nil
              binding = nil
              item["db:attribute"].each do |av|
                isbn = av["$t"] if av["@name"] == "isbn13"
                publisher = av["$t"] if av["@name"] == "publisher"
                pubdate = av["$t"] if av["@name"] == "pubdate"
                binding = av["$t"] if av["@name"] == "binding"
              end
              authors = if item["author"]
                          item["author"].map { |a| a["name"]["$t"] }
                        else
                          []
                        end
              image_url = nil
              item["link"].each do |av|
                image_url = av["@href"] if av["@rel"] == "image"
              end
              book = Book.new(name, authors, isbn, publisher, pubdate, binding)
              book_search_results << [book, image_url]
            end
          end
        rescue StandardError => ex
          log.warn(ex.backtrace.join('\n'))
        end
        book_search_results
      end
    end
  end
end
