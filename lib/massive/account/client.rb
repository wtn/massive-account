require 'date'
require_relative 'authentication'
require_relative 'api'
require_relative 'keys'

module Massive
  module Account
    # Client for interacting with massive.com account
    class Client
      attr_reader :account_id, :token

      # Creates a new client by authenticating with email and password
      #
      # @param email [String] The user's email address
      # @param password [String] The user's password
      # @return [Client, nil] Authenticated client or nil if authentication fails
      # @raise [ArgumentError] if email or password is missing
      def self.sign_in(email:, password:)
        raise ArgumentError, "email is required" if email.nil? || email.empty?
        raise ArgumentError, "password is required" if password.nil? || password.empty?

        credentials = Authentication.authenticate(email, password)
        return nil unless credentials

        new(
          account_id: credentials[:account_id],
          token: credentials[:token],
        )
      end

      # Creates a client with existing credentials
      #
      # @param account_id [String] The account UUID
      # @param token [String] The session token
      def initialize(account_id:, token:)
        @account_id = account_id
        @token = token
      end

      # Fetches all API keys
      #
      # @return [Array<Hash>] Array of API key hashes
      def keys
        Keys.fetch(@account_id, token: @token)
      end

      # Fetches detailed information for a specific key
      #
      # @param key_id [String] The key UUID
      # @return [Hash, nil] Hash with key details including S3 credentials
      def key_details(key_id)
        Keys.fetch_key_details(@account_id, key_id, token: @token)
      end

      # Fetches comprehensive account information from Polygon API
      #
      # This is an API-first implementation that uses data from api.polygon.io
      # and minimal dashboard scraping (only for API keys/S3 credentials).
      #
      # @return [Hash] Complete account information structured for easy access
      # @example
      #   info = client.account_info
      #   # => {
      #   #   account_id: "uuid-here",
      #   #   email: "user@example.com",
      #   #   subscription_id: "sub_...",
      #   #   provider: "polygon",
      #   #   billing_interval: "month",
      #   #   account_type: "user",
      #   #   email_verified: false,
      #   #   created_utc: "2022-12-14T00:41:50.212Z",
      #   #   updated_utc: "2025-08-07T06:14:50.754Z",
      #   #   payment_id: "cus_...",
      #   #   asset_classes: [:stocks, :currencies, :indices, :options],
      #   #   assets: {
      #   #     stocks: {
      #   #       websocket_connection_limit: 1,
      #   #       rest_rate_limit: { requests: 99, window: 1 }
      #   #     },
      #   #     currencies: {
      #   #       websocket_connection_limit: 0,
      #   #       rest_rate_limit: { requests: 5, window: 60 }
      #   #     }
      #   #   },
      #   #   credential_sets: [
      #   #     {
      #   #       id: "uuid",
      #   #       name: "Default",
      #   #       api_key: "massive_...",
      #   #       s3: { access_key_id: "...", secret_access_key: "...", ... }
      #   #     }
      #   #   ]
      #   # }
      def account_info
        @account_info ||= begin
          # Fetch account data from Polygon API (primary data source)
          api_data = API.fetch_account(@account_id, token: @token) || {}

          # Derive asset classes from API data
          # Asset classes = union of websocket and rate_limit keys
          websocket_assets = (api_data[:max_websocket_connections_by_asset_type]&.keys || [])
          rate_limit_assets = (api_data[:rate_limit_by_asset_type]&.keys || [])
          asset_classes = (websocket_assets + rate_limit_assets).uniq.map(&:to_sym).sort

          # Build per-asset configuration
          assets = {}
          asset_classes.each do |asset|
            # WebSocket connection limit (0 or greater)
            websocket_limit = api_data.dig(:max_websocket_connections_by_asset_type, asset) || 0

            # REST API rate limit
            # If in rate_limit_by_asset_type: assume it's per minute (window: 60)
            # If NOT in rate_limit_by_asset_type: assume unlimited (99 requests per second)
            api_limit = api_data.dig(:rate_limit_by_asset_type, asset)
            rest_limit = if api_limit
              { requests: api_limit, window: 60 }  # Assume per minute
            else
              { requests: 99, window: 1 }  # Unlimited = 99/sec
            end

            assets[asset] = {
              websocket_connection_limit: websocket_limit,
              rest_rate_limit: rest_limit
            }
          end

          # Fetch credential sets (still need dashboard scraping for API keys/S3)
          api_keys_list = keys

          # Fetch detailed information for each credential set (including S3 credentials)
          credential_sets = api_keys_list.map do |key|
            details = key_details(key[:id]) || {}

            {
              id: key[:id],
              name: key[:name],
              api_key: key[:key],
              created_at: key[:created_at],
              s3: {
                access_key_id: details[:s3_access_key_id],
                secret_access_key: details[:s3_secret_access_key],
                endpoint: details[:s3_endpoint],
                bucket: details[:s3_bucket],
              }.compact,
            }.compact
          end

          # Build complete account info from API data
          {
            account_id: @account_id,
            email: api_data[:email],
            subscription_id: api_data[:subscription_id],
            provider: api_data[:provider],
            billing_interval: api_data[:billing_interval],
            account_type: api_data[:account_type],
            email_verified: api_data[:email_verified],
            created_utc: api_data[:created_utc],
            updated_utc: api_data[:updated_utc],
            payment_id: api_data[:payment_id],
            asset_classes: asset_classes,
            assets: assets,
            credential_sets: credential_sets,
          }.compact
        end
      end

      # Returns the primary credential set
      #
      # Priority order:
      # 1. Credential named "Default" (if exists)
      # 2. Last credential in list (oldest)
      #
      # @return [Hash, nil] Primary credential set with API key and S3 credentials
      def primary_credential_set
        creds = account_info[:credential_sets]
        return nil if creds.empty?

        # Prefer "Default" if it exists
        default = creds.find { |c| c[:name]&.match?(/^default$/i) }
        return default if default

        # Otherwise use last (oldest)
        creds.last
      end

      # Returns all asset classes supported by the account
      #
      # @return [Array<Symbol>] Array of asset class symbols
      # @example
      #   client.asset_classes  # => [:currencies, :indices, :options, :stocks]
      def asset_classes
        account_info[:asset_classes]
      end

      # Returns REST API rate limit for a specific asset class
      #
      # @param asset_class [String, Symbol] The asset class name (stocks, options, currencies, indices)
      # @return [Hash, nil] Hash with :requests and :window, or nil if not found
      # @example
      #   limit = client.rest_rate_limit(:stocks)
      #   # => { requests: 99, window: 1 }
      def rest_rate_limit(asset_class)
        asset_key = asset_class.to_sym
        account_info[:assets][asset_key]&.dig(:rest_rate_limit)
      end

      # Returns REST API rate limits for all asset classes
      #
      # @return [Hash] Hash mapping asset class symbols to rate limit hashes
      # @example
      #   limits = client.rest_rate_limits
      #   # => { stocks: { requests: 99, window: 1 }, options: { requests: 5, window: 60 } }
      def rest_rate_limits
        account_info[:assets].transform_values { |a| a[:rest_rate_limit] }.compact
      end

      # Returns WebSocket connection limit for an asset class
      #
      # @param asset_class [String, Symbol] The asset class name (stocks, options, currencies, indices)
      # @return [Integer] Maximum number of concurrent WebSocket connections (0 if WebSocket not available)
      # @example
      #   client.websocket_connection_limit(:stocks)  # => 1
      #   client.websocket_connection_limit(:currencies)  # => 0
      def websocket_connection_limit(asset_class)
        asset_key = asset_class.to_sym
        account_info[:assets][asset_key]&.dig(:websocket_connection_limit) || 0
      end
    end
  end
end
