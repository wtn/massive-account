require 'net/http'
require 'uri'
require 'json'

module Massive
  module Account
    # Handles direct API calls to api.polygon.io
    # @private
    module API
      module_function

      # Fetches account information from the Polygon API
      #
      # This provides structured account data including rate limits,
      # subscription info, and product IDs. More reliable than scraping
      # but may have less detail than dashboard pages.
      #
      # @param account_id [String] The account UUID
      # @param token [String] The session token
      # @return [Hash, nil] Account data hash or nil if request fails
      def fetch_account(account_id, token:)
        uri = URI('https://api.polygon.io/accountservices/v1/accounts')
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(uri)
        request['Cookie'] = "polygon-token=#{token}"

        response = http.request(request)
        return nil unless response.code.to_i.between?(200, 299)

        data = JSON.parse(response.body)
        results = data['results']
        return nil unless results&.any?

        # Find the matching account by ID
        account = results.find { |a| a['id'] == account_id }
        return nil unless account

        # Convert to symbol keys for consistency with rest of gem
        symbolize_keys(account)
      rescue JSON::ParserError, StandardError
        nil
      end

      # Recursively converts string keys to symbols
      def self.symbolize_keys(obj)
        case obj
        when Hash
          obj.transform_keys(&:to_sym).transform_values { |v| symbolize_keys(v) }
        when Array
          obj.map { |v| symbolize_keys(v) }
        else
          obj
        end
      end
    end
  end
end
