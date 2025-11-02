require 'date'
require_relative 'authentication'
require_relative 'resources'
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

      # Fetches account resources (subscriptions)
      #
      # @return [Hash] Hash of resources grouped by category
      def resources
        Resources.fetch(@account_id, token: @token)
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

      # Fetches comprehensive account information including all subscriptions
      # and credential sets in one call
      #
      # Combines data from both the Polygon API (for structured account metadata)
      # and dashboard scraping (for detailed product information).
      #
      # Each credential set includes both an API key (for REST/WebSocket access)
      # and S3 credentials (for flat file access). Accounts can have multiple
      # credential sets.
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
      #   #   resources: {
      #   #     stocks: {
      #   #       tier: "starter",
      #   #       historical_years: 5,
      #   #       rate_limit: { requests: 99, window: 1 },
      #   #       realtime: false,
      #   #       delay_minutes: 15,
      #   #       websocket: true,
      #   #       features: { flat_files: true, snapshot: true, ... }
      #   #     },
      #   #     options: { tier: "basic", historical_years: 2, ... }
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
          # Fetch account data from Polygon API (structured metadata)
          api_data = API.fetch_account(@account_id, token: @token) || {}

          # Fetch all resources (product subscriptions) from dashboard
          raw_resources = resources

          # Normalize resource data - parse strings into usable values
          # Also convert keys to symbols for consistency
          normalized_resources = raw_resources.transform_keys do |key|
            key.to_sym
          end.transform_values do |resource_data|
            normalize_resource(resource_data)
          end

          # Enhance normalized resources with API rate limit data
          # API provides structured rate limits (but may be incomplete)
          if api_data[:rate_limit_by_asset_type]
            api_data[:rate_limit_by_asset_type].each do |asset_type, limit|
              asset_key = asset_type.to_sym

              # Only use API rate limit if we don't have one from scraping
              # or if API provides a window specification
              if normalized_resources[asset_key]
                normalized_resources[asset_key][:api_rate_limit] = limit
              end
            end
          end

          # Fetch all credential sets (API keys)
          api_keys_list = keys

          # Fetch detailed information for each credential set (including S3 credentials)
          credential_sets = api_keys_list.map do |key|
            # Get full details for this credential set
            details = key_details(key[:id]) || {}

            # Build complete credential set with both API key and S3 credentials
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

          # Determine if account is paid (any resource above basic tier)
          paid = normalized_resources.values.any? { |r| r[:tier] && r[:tier] != "basic" }

          # Build complete account info, merging API and scraped data
          {
            account_id: @account_id,
            email: api_data[:email],
            subscription_id: api_data[:subscription_id],
            provider: api_data[:provider],
            billing_interval: api_data[:billing_interval],
            resources: normalized_resources,
            credential_sets: credential_sets,
            paid: paid,
          }.compact
        end
      end

      private

      # Normalize raw resource data into clean, parsed values
      def normalize_resource(resource_data)
        features = resource_data[:features]
        plan = resource_data[:plan]

        # Parse tier from plan name
        tier = if plan =~ /\b(basic|starter|developer|advanced)\b/i
          $1.downcase
        end

        # Parse historical years
        historical_years = if (hist = features["historical_data"]) && hist =~ /(\d+)\+?\s*Years?/i
          $1.to_i
        end

        # Parse rate limit
        rate_limit = parse_rate_limit(features["api_calls"])

        # Parse realtime/delay
        realtime, delay_minutes = parse_timeframe(features["timeframe"])

        # Build normalized structure
        normalized = {
          tier: tier,
          historical_years: historical_years,
          rate_limit: rate_limit,
          realtime: realtime,
          delay_minutes: delay_minutes,
          websocket: features["websocket"] == "available",
        }

        # Add tier-specific features (only if present)
        tier_features = {}
        tier_features[:flat_files] = true if features["flat_files"] == "available"
        tier_features[:snapshot] = true if features["snapshot"] == "available"
        tier_features[:second_aggregates] = true if features["second_aggregates"] == "available"
        tier_features[:trades] = true if features["trades"] == "available"
        tier_features[:quotes] = true if features["quotes"] == "available"
        tier_features[:financials] = true if features["financials"] == "available"

        normalized[:features] = tier_features unless tier_features.empty?

        normalized.compact
      end

      def parse_rate_limit(api_calls)
        return nil unless api_calls

        if api_calls =~ /unlimited/i
          { requests: 99, window: 1 }
        elsif api_calls =~ /(\d+)\s*API\s*Calls?\s*\/\s*Minute/i
          { requests: $1.to_i, window: 60 }
        elsif api_calls =~ /(\d+)\s*API\s*Calls?\s*\/\s*Second/i
          { requests: $1.to_i, window: 1 }
        end
      end

      def parse_timeframe(timeframe)
        return [false, 0] unless timeframe

        if timeframe =~ /real-?time/i
          [true, 0]
        elsif timeframe =~ /(\d+)-?minute\s+delayed/i
          [false, $1.to_i]
        elsif timeframe =~ /end\s+of\s+day/i
          [false, 0]  # EOD = 0 delay (data is from previous day)
        else
          [false, 0]
        end
      end

      public

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

      # Returns rate limit for a specific resource (asset class)
      #
      # @param resource [String, Symbol] The resource name (stocks, options, futures, indices, currencies)
      # @return [Hash, nil] Hash with :requests and :window, or nil if not found
      # @example
      #   limit = client.rate_limit(:stocks)
      #   # => { requests: 99, window: 1 }
      def rate_limit(resource)
        resource_key = resource.to_sym
        account_info[:resources][resource_key]&.dig(:rate_limit)
      end

      # Returns rate limits for all resources
      #
      # @return [Hash] Hash mapping resource symbols to rate limit hashes
      # @example
      #   limits = client.rate_limits
      #   # => { stocks: { requests: 99, window: 1 }, options: { requests: 5, window: 60 } }
      def rate_limits
        account_info[:resources].transform_values { |r| r[:rate_limit] }.compact
      end

      # Returns historical data period in years for a specific resource
      #
      # @param resource [String, Symbol] The resource name (stocks, options, futures, indices, currencies)
      # @return [Integer, nil] Number of years of historical data, or nil if not found
      # @example
      #   years = client.historical_years(:stocks)
      #   # => 5
      def historical_years(resource)
        resource_key = resource.to_sym
        account_info[:resources][resource_key]&.dig(:historical_years)
      end

      # Returns the cutoff date for historical data based on subscription
      #
      # NOTE: Server testing shows "2 Years Historical Data" actually provides ~5 years (1825 days).
      # The server uses simple day arithmetic (years * 365), not calendar years.
      # This method returns a conservative estimate based on the ADVERTISED period.
      #
      # @param resource [String, Symbol] The resource name (stocks, options, futures, indices, currencies)
      # @return [Date, nil] Earliest date for which historical data should be available
      # @example
      #   cutoff = client.historical_cutoff_date(:stocks)
      #   # => #<Date: 2023-11-03> (730 days ago for "2 Years Historical Data")
      def historical_cutoff_date(resource)
        years = historical_years(resource)
        return nil unless years

        # Server uses simple day arithmetic: years * 365
        # Testing confirmed: "2 Years" → actually 1825 days (5*365) are available
        # But we return conservative estimate based on advertised period
        Date.today - (years * 365)
      end

      # Returns the cutoff time for historical data based on subscription
      #
      # NOTE: Server testing shows "2 Years Historical Data" actually provides ~5 years (1825 days).
      # The server uses simple day arithmetic (years * 365), not calendar years.
      # This method returns a conservative estimate based on the ADVERTISED period.
      #
      # @param resource [String, Symbol] The resource name (stocks, options, futures, indices, currencies)
      # @return [Time, nil] Earliest time for which historical data should be available
      # @example
      #   cutoff = client.historical_cutoff_time(:stocks)
      #   # => 2023-11-03 12:30:00 -0600 (730 days ago)
      def historical_cutoff_time(resource)
        years = historical_years(resource)
        return nil unless years

        # Server uses simple seconds arithmetic: years * 365 * 24 * 60 * 60
        Time.now - (years * 365 * 24 * 60 * 60)
      end

      # Returns whether a resource has real-time (non-delayed) data access
      #
      # @param resource [String, Symbol] The resource name (stocks, options, futures, indices, currencies)
      # @return [Boolean] True if real-time, false if delayed or end-of-day
      # @example
      #   client.realtime?(:stocks)  # => false
      def realtime?(resource)
        resource_key = resource.to_sym
        account_info[:resources][resource_key]&.dig(:realtime) || false
      end

      # Returns whether a resource has WebSocket access
      #
      # @param resource [String, Symbol] The resource name (stocks, options, futures, indices, currencies)
      # @return [Boolean] True if WebSocket is available
      # @example
      #   client.websocket?(:stocks)  # => true
      def websocket?(resource)
        resource_key = resource.to_sym
        account_info[:resources][resource_key]&.dig(:websocket) || false
      end

      # Returns the subscription tier for a specific resource
      #
      # @param resource [String, Symbol] The resource name (stocks, options, futures, indices, currencies)
      # @return [String, nil] Tier name (basic, starter, developer, advanced)
      # @example
      #   tier = client.tier(:stocks)
      #   # => "starter"
      def tier(resource)
        resource_key = resource.to_sym
        account_info[:resources][resource_key]&.dig(:tier)
      end

      # Returns all tiers for subscribed resources
      #
      # @return [Hash] Hash mapping resource symbols to tier names
      # @example
      #   tiers = client.tiers
      #   # => { stocks: "starter", options: "basic" }
      def tiers
        account_info[:resources].transform_values { |r| r[:tier] }.compact
      end
    end
  end
end
