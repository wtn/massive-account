require 'net/http'
require 'uri'
require 'json'
require 'base64'

module Massive
  module Account
    module Keys
      # Fetches API keys for the account
      #
      # @param account_id [String] The account UUID
      # @param token [String] Session token for authentication (required)
      # @return [Array<Hash>] Array of API key hashes with :id, :name, :key, :created_at
      # @raise [ArgumentError] if account_id or token is missing
      def self.fetch(account_id, token:)
        raise ArgumentError, 'account_id is required' if account_id.nil? || account_id.empty?
        raise ArgumentError, 'token is required for API keys access' if token.nil? || token.empty?

        # Create authentication cookies
        cookie = create_cookie(account_id, token)

        # Fetch keys page to get RSC payload with API keys data
        response = fetch_keys_page(cookie)
        return [] unless response&.code == '200'

        # Parse RSC payload to extract keys
        parse_keys(response.body)
      end

      # Fetches detailed information for a specific key including S3 credentials
      #
      # @param account_id [String] The account UUID
      # @param key_id [String] The key UUID
      # @param token [String] Session token for authentication (required)
      # @return [Hash, nil] Hash with key details including S3 credentials
      # @raise [ArgumentError] if parameters are missing
      def self.fetch_key_details(account_id, key_id, token:)
        raise ArgumentError, 'account_id is required' if account_id.nil? || account_id.empty?
        raise ArgumentError, 'key_id is required' if key_id.nil? || key_id.empty?
        raise ArgumentError, 'token is required' if token.nil? || token.empty?

        # Create authentication cookies
        cookie = create_cookie(account_id, token)

        # Fetch specific key page
        response = fetch_key_detail_page(cookie, key_id)
        return nil unless response&.code == '200'

        # Parse RSC payload to extract key details
        parse_key_details(response.body)
      end

      private

      def self.create_cookie(account_id, token)
        json_data = { id: account_id }.to_json
        base64_encoded = Base64.strict_encode64(json_data)
        "massive-account=#{base64_encoded}; massive-token=#{token}"
      end

      def self.fetch_keys_page(cookie)
        client = HTTPClient.new(cookie: cookie)
        client.get('/dashboard/keys')
      end

      def self.fetch_key_detail_page(cookie, key_id)
        client = HTTPClient.new(cookie: cookie)
        client.get("/dashboard/keys/#{key_id}")
      end

      def self.parse_keys(html)
        rsc_text = HTTPClient.extract_rsc_payload(html)

        # Look for the rows array in the keys table
        # Structure: "rows":[{"name":"...","key":"...","id":"..."},...]
        if rsc_text =~ /"rows":\s*\[(.*?)\]/m
          rows_json = "[#{$1}]"

          begin
            rows = JSON.parse(rows_json)

            # Convert to our format
            return rows.map do |row|
              {
                name: row['name'],
                key: row['key'],
                id: row['id'],
                created_at: row['created_at'],
              }
            end
          rescue JSON::ParserError
            # Fall back to simple key extraction
          end
        end

        # Fallback: just extract key values
        key_values = rsc_text.scan(/"key":\s*"([a-zA-Z0-9_-]{30,})"/).flatten.uniq
        key_values.map do |key_value|
          {
            key: key_value,
            name: nil,
            id: nil,
            created_at: nil,
          }
        end
      end

      def self.parse_key_details(html)
        rsc_text = HTTPClient.extract_rsc_payload(html)

        details = {}

        # Extract name and keyId
        if rsc_text =~ /"name":"([^"]+)","keyId":"([^"]+)"/
          details[:name] = $1
          details[:id] = $2
        end

        # Extract API key
        if rsc_text =~ /"accessKey":"([^"]+)"/
          details[:api_key] = $1
        end

        # Extract S3 credentials from the flat-files tab
        # Pattern: "Access Key ID" followed by the value
        if rsc_text =~ /"Access Key ID".*?"children":"([^"]+)"/m
          details[:s3_access_key_id] = $1
        end

        # Secret Access Key
        if rsc_text =~ /"Secret Access Key".*?"children":"([^"]+)"/m
          details[:s3_secret_access_key] = $1
        end

        # S3 Endpoint
        if rsc_text =~ /"S3 Endpoint".*?"children":"([^"]+)"/m
          details[:s3_endpoint] = $1
        end

        # Bucket
        if rsc_text =~ /"Bucket".*?"children":"([^"]+)"/m
          details[:s3_bucket] = $1
        end

        details
      end
    end
  end
end
