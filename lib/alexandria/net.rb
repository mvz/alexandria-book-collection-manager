# -*- ruby -*-

module Alexandria


  class WWWAgent
    def initialize()
      user_agent = "Ruby #{RUBY_VERSION} #{Alexandria::TITLE}/#{Alexandria::VERSION}"
      @extra_request_headers = {"User-Agent" => user_agent}
    end

    def self.transport
      config = Alexandria::Preferences.instance.http_proxy_config
      config ? Net::HTTP.Proxy(*config) : Net::HTTP
    end

    def get(url)
      uri = URI.parse(url)
      req = Net::HTTP::Get.new(uri.request_uri)
      @extra_request_headers.each_pair do |header_name, value|
        req.add_field(header_name, value)
      end          
      res = WWWAgent.transport.start(uri.host, uri.port) {|http|
        http.request(req)
      }
      res
    end
    
    def language=(lang)
      @extra_request_headers["Accept-Language"] = lang.to_s
    end

    def user_agent=(agent_string)      
      @extra_request_headers["User-Agent"] = agent_string
    end
  end
  
end
