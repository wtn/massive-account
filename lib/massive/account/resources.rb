require 'net/http'
require 'uri'
require 'json'
require 'base64'

module Massive
  module Account
    module Resources
      # Fetches available resources for the account
      #
      # @param account_id [String] The account UUID
      # @param token [String, nil] Optional session token for authentication
      # @return [Hash] Hash of resources grouped by category (stocks, options, currencies, indices)
      # @raise [ArgumentError] if account_id is missing
      def self.fetch(account_id, token: nil)
        raise ArgumentError, "account_id is required" if account_id.nil? || account_id.empty?

        # Create authentication cookies
        cookie = create_cookie(account_id, token)

        # Fetch subscriptions page to get RSC payload with subscription data
        response = fetch_subscriptions_page(cookie)
        return {} unless response&.code == '200'

        # Parse RSC payload to extract resources
        parse_resources(response.body)
      end

      private

      def self.create_cookie(account_id, token = nil)
        json_data = { id: account_id }.to_json
        base64_encoded = Base64.strict_encode64(json_data)

        cookies = ["massive-account=#{base64_encoded}"]
        cookies << "massive-token=#{token}" if token
        cookies.join('; ')
      end

      def self.fetch_subscriptions_page(cookie)
        client = HTTPClient.new(cookie: cookie)
        client.get('/dashboard/subscriptions')
      end

      def self.parse_resources(html)
        rsc_text = HTTPClient.extract_rsc_payload(html)

        # Check if we have product data in the payload
        return {} unless rsc_text.include?('product_line') || rsc_text.include?('subscription_items')

        # Extract subscription items from RSC payload
        subscription_items = []
        product_blocks = rsc_text.split('"product":')

        product_blocks[1..-1].each do |block|
          # Extract product name
          next unless block =~ /"name":"([^"]+)"/
          product_name = $1

          # Extract features - need to handle nested braces properly
          next unless block =~ /"features":\{([^}]+(?:\}[^}]*)*?)\}/m
          features_str = $1

          # Parse features
          features = {}
          features_str.scan(/"([^"]+)":"([^"]+)"/m).each do |k, v|
            next if v == "$undefined" || v == "unavailable"
            features[k] = v
          end

          next if features.empty?

          subscription_items << {
            name: product_name,
            features: features,
          }
        end

        # Group by category
        resources = {}
        subscription_items.each do |item|
          category = item[:name].downcase.split.first

          resources[category] = {
            plan: item[:name],
            features: item[:features],
          }
        end

        resources
      end
    end
  end
end
