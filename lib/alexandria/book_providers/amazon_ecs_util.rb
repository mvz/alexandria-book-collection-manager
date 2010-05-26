#--
# Copyright (c) 2006 Herryanto Siatono, Pluit Solutions
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

# Modified by Cathal Mc Ginley 2008-02-18
# added Amazon::Ecs.transport - to enable Alexandria's proxy support
# Modified by Cathal Mc Ginley 2008-08-26
# Amazon::Element.get now uses inner_text, not inner_html, fixing #21659
# Modified by Cathal Mc Ginley 2009-08-13
# Added sign_request and hmac_sha256 methods for Authentication support

require 'net/http'
require 'hpricot'
require 'cgi'

require 'digest/sha2'


module Amazon
  class RequestError < StandardError; end

  class Ecs
    include Alexandria::Logging

    SERVICE_URLS = {:us => 'http://webservices.amazon.com/onca/xml?Service=AWSECommerceService',
        :uk => 'http://webservices.amazon.co.uk/onca/xml?Service=AWSECommerceService',
        :ca => 'http://webservices.amazon.ca/onca/xml?Service=AWSECommerceService',
        :de => 'http://webservices.amazon.de/onca/xml?Service=AWSECommerceService',
        :jp => 'http://webservices.amazon.co.jp/onca/xml?Service=AWSECommerceService',
        :fr => 'http://webservices.amazon.fr/onca/xml?Service=AWSECommerceService'
    }

    @@options = {}
    @@debug = false

    @@secret_access_key = ''

    # Default search options
    def self.options
      @@options
    end

    def self.secret_access_key=(key)
      @@secret_access_key = key
    end

    # Set default search options
    def self.options=(opts)
      @@options = opts
    end

    # Get debug flag.
    def self.debug
      @@debug
    end

    # Set debug flag to true or false.
    def self.debug=(dbg)
      @@debug = dbg
    end

    def self.configure(&proc)
      raise ArgumentError, "Block is required." unless block_given?
      yield @@options
    end

    # Search amazon items with search terms. Default search index option is 'Books'.
    # For other search type other than keywords, please specify :type => [search type param name].
    def self.item_search(terms, opts = {})
      opts[:operation] = 'ItemSearch'
      opts[:search_index] = opts[:search_index] || 'Books'

      type = opts.delete(:type)
      if type
        opts[type.to_sym] = terms
      else
        opts[:keywords] = terms
      end

      self.send_request(opts)
    end

    # Search an item by ASIN no.
    def self.item_lookup(item_id, opts = {})
      opts[:operation] = 'ItemLookup'
      opts[:item_id] = item_id

      self.send_request(opts)
    end

    # HACK : copied from book_providers.rb
    def self.transport
      config = Alexandria::Preferences.instance.http_proxy_config
      config ? Net::HTTP.Proxy(*config) : Net::HTTP
    end


    # Generic send request to ECS REST service. You have to specify the :operation parameter.
    def self.send_request(opts)
      opts = self.options.merge(opts) if self.options
      request_url = prepare_url(opts)
      log.debug { "Request URL: #{request_url}" }

      res = self.transport.get_response(URI::parse(request_url))
      unless res.kind_of? Net::HTTPSuccess
        raise Amazon::RequestError, "HTTP Response: #{res.code} #{res.message}"
      end
      Response.new(res.body)
    end

    # Response object returned after a REST call to Amazon service.
    class Response
      # XML input is in string format
      def initialize(xml)
        @doc = Hpricot(xml)
      end

      # Return Hpricot object.
      def doc
        @doc
      end

      # Return true if request is valid.
      def is_valid_request?
        (@doc/"isvalid").inner_html == "True"
      end

      # Return true if response has an error.
      def has_error?
        !(error.nil? || error.empty?)
      end

      # Return error message.
      def error
        Element.get(@doc, "error/message")
      end

      # Return an array of Amazon::Element item objects.
      def items
        unless @items
          @items = (@doc/"item").collect {|item| Element.new(item)}
        end
        @items
      end

      # Return the first item (Amazon::Element)
      def first_item
        items.first
      end

      # Return current page no if :item_page option is when initiating the request.
      def item_page
        unless @item_page
          @item_page = (@doc/"itemsearchrequest/itempage").inner_html.to_i
        end
        @item_page
      end

      # Return total results.
      def total_results
        unless @total_results
          @total_results = (@doc/"totalresults").inner_html.to_i
        end
        @total_results
      end

      # Return total pages.
      def total_pages
        unless @total_pages
          @total_pages = (@doc/"totalpages").inner_html.to_i
        end
        @total_pages
      end
    end

    #protected
    #  def self.log(s)
    #    return unless self.debug
    #    if defined? RAILS_DEFAULT_LOGGER
    #      RAILS_DEFAULT_LOGGER.error(s)
    #    elsif defined? LOGGER
    #      LOGGER.error(s)
    #    else
    #      puts s
    #    end
    #  end

    private
      def self.prepare_url(opts)
        country = opts.delete(:country)
        country = (country.nil?) ? 'us' : country
        request_url = SERVICE_URLS[country.to_sym]
        raise Amazon::RequestError, "Invalid country '#{country}'" unless request_url

        qs = ''
        opts.each {|k,v|
          next unless v
          v = v.join(',') if v.is_a? Array
          qs << "&#{camelize(k.to_s)}=#{URI.encode(v.to_s)}"
        }
        url = "#{request_url}#{qs}"
        #puts ">>> base url >> #{url}"
        signed_url = sign_request(url)
        #puts ">>> SIGNED >> #{signed_url}"
        signed_url
      end

      def self.camelize(s)
        s.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
      end



    def self.hmac_sha256(message, key)
      block_size = 64 
      ipad = "\x36" * block_size
      opad = "\x5c" * block_size
      if key.size > block_size
        d = Digest::SHA256.new
        key = d.digest(key)
      end
      
      ipad_bytes = ipad.bytes.collect {|b| b }
      opad_bytes = opad.bytes.collect {|b| b }
      key_bytes = key.bytes.collect {|b| b}
      ipad_xor = ""
      opad_xor = ""
      for i in 0 .. key.size - 1       
        ipad_xor << (ipad_bytes[i] ^ key_bytes[i])
        opad_xor << (opad_bytes[i] ^ key_bytes[i])
      end
      
      ipad = ipad_xor + ipad[key.size..-1]
      opad = opad_xor + opad[key.size..-1]

      # inner hash
      d1 = Digest::SHA256.new
      d1.update(ipad)
      d1.update(message)
      msg_hash = d1.digest()
      
      # outer hash
      d2 = Digest::SHA256.new
      d2.update(opad)
      d2.update(msg_hash)
      d2.digest
    end

    def self.sign_request(request)
      raise AmazonNotConfiguredError unless @@secret_access_key
      # Step 0 : Split apart request string
      url_pattern = /http:\/\/([^\/]+)(\/[^\?]+)\?(.*$)/ 
      url_pattern =~ request
      host = $1
      path = $2
      param_string = $3
      
      # Step 1: enter the timestamp
      t = Time.now.getutc # MUST be in UTC
      stamp = t.strftime('%Y-%m-%dT%H:%M:%SZ')
      param_string = param_string + "&Timestamp=#{stamp}"
      
      # Step 2 : URL-encode
      param_string = param_string.gsub(',', '%2C').gsub(':', '%3A')
      #   NOTE : take care not to double-encode
      
      # Step 3 : Split the parameter/value pairs
      params = param_string.split('&')
      
      # Step 4 : Sort params
      params.sort!
      
      # Step 5 : Rejoin the param string
      canonical_param_string = params.join('&')
      
      # Steps 6 & 7: Prepend HTTP request info
      string_to_sign = "GET\n#{host}\n#{path}\n#{canonical_param_string}"
      
      #puts string_to_sign

      # Step 8 : Calculate RFC 2104-compliant HMAC with SHA256 hash algorithm
      sig = hmac_sha256(string_to_sign, @@secret_access_key)     
      base64_sig = [sig].pack('m').strip
      
      # Step 9 : URL-encode + and = in sig
      base64_sig = CGI.escape(base64_sig)
      
      # Step 10 : Add the URL encoded signature to your request
      "http://#{host}#{path}?#{param_string}&Signature=#{base64_sig}"
    end



  end

  # Internal wrapper class to provide convenient method to access Hpricot element value.
  class Element
    # Pass Hpricot::Elements object
    def initialize(element)
      @element = element
    end

    # Returns Hpricot::Elments object
    def elem
      @element
    end

    # Find Hpricot::Elements matching the given path. Example: element/"author".
    def /(path)
      elements = @element/path
      return nil if elements.size == 0
      elements
    end

    # Find Hpricot::Elements matching the given path, and convert to Amazon::Element.
    # Returns an array Amazon::Elements if more than Hpricot::Elements size is greater than 1.
    def search_and_convert(path)
      elements = self./(path)
      return unless elements
      elements = elements.map{|element| Element.new(element)}
      return elements.first if elements.size == 1
      elements
    end

    # Get the text value of the given path, leave empty to retrieve current element value.
    def get(path='')
      Element.get(@element, path)
    end

    # Get the unescaped HTML text of the given path.
    def get_unescaped(path='')
      Element.get_unescaped(@element, path)
    end

    # Get the array values of the given path.
    def get_array(path='')
      Element.get_array(@element, path)
    end

    # Get the children element text values in hash format with the element names as the hash keys.
    def get_hash(path='')
      Element.get_hash(@element, path)
    end

    # Similar to #get, except an element object must be passed-in.
    def self.get(element, path='')
      return unless element
      result = element.at(path)
      ## inner_html doesn't decode entities, hence bug #21659
      # result = result.inner_html if result
      result = result.inner_text if result
      result
    end

    # Similar to #get_unescaped, except an element object must be passed-in.
    def self.get_unescaped(element, path='')
      result = get(element, path)
      CGI::unescapeHTML(result) if result
    end

    # Similar to #get_array, except an element object must be passed-in.
    def self.get_array(element, path='')
      return unless element

      result = element/path
      if (result.is_a? Hpricot::Elements) || (result.is_a? Array)
        parsed_result = []
        result.each {|item|
          parsed_result << Element.get(item)
        }
        parsed_result
      else
        [Element.get(result)]
      end
    end

    # Similar to #get_hash, except an element object must be passed-in.
    def self.get_hash(element, path='')
      return unless element

      result = element.at(path)
      if result
        hash = {}
        result = result.children
        result.each do |item|
          hash[item.name.to_sym] = item.inner_html
        end
        hash
      end
    end

    def to_s
      elem.to_s if elem
    end
  end
end
