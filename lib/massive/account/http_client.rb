require 'net/http'
require 'uri'
require 'json'

module Massive
  module Account
    # Internal HTTP client for making requests to massive.com
    # @private
    class HTTPClient
      def initialize(cookie: nil)
        @cookie = cookie
      end

      def base_uri
        URI::HTTPS.build(host: 'massive.com')
      end

      # Performs a GET request
      def get(path)
        uri = base_uri.dup
        uri.path = path

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(uri.path)
        request['Cookie'] = @cookie if @cookie

        http.request(request)
      rescue StandardError
        nil
      end

      # Performs a POST request with multipart form data
      def post(path, fields:, headers: {})
        uri = base_uri.dup
        uri.path = path

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri.path)
        request['Cookie'] = @cookie if @cookie
        headers.each { |k, v| request[k] = v }
        request.set_form(fields, 'multipart/form-data')

        http.request(request)
      rescue StandardError
        nil
      end

      # Extracts RSC payload from HTML response
      def self.extract_rsc_payload(html)
        rsc_text = String.new
        html.scan(/self\.__next_f\.push\(\[(.*?)\]\)/m).each do |match|
          begin
            payload_array = JSON.parse("[#{match[0]}]")
            rsc_text += payload_array[1].to_s if payload_array[1]
          rescue JSON::ParserError
            rsc_text += match[0]
          end
        end
        rsc_text
      end
    end
  end
end
