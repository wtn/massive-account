require_relative 'account/version'
require_relative 'account/http_client'
require_relative 'account/authentication'
require_relative 'account/api'
require_relative 'account/keys'
require_relative 'account/client'

module Massive
  module Account
    class Error < StandardError; end

    # Get account information (convenience method)
    #
    # Defaults to MASSIVE_ACCOUNT_EMAIL and MASSIVE_ACCOUNT_PASSWORD environment variables.
    # Most common usage: just call Massive::Account.info to get everything.
    #
    # @param email [String, nil] Email (defaults to ENV['MASSIVE_ACCOUNT_EMAIL'])
    # @param password [String, nil] Password (defaults to ENV['MASSIVE_ACCOUNT_PASSWORD'])
    # @return [Hash] Complete account information (same as Client#account_info)
    # @raise [ArgumentError] if credentials not provided via params or ENV
    # @example
    #   # Using environment variables
    #   info = Massive::Account.info
    #
    #   # Or pass explicitly
    #   info = Massive::Account.info(email: "user@example.com", password: "pass")
    def self.info(email: ENV['MASSIVE_ACCOUNT_EMAIL'], password: ENV['MASSIVE_ACCOUNT_PASSWORD'])
      raise ArgumentError, 'email required (via argument or MASSIVE_ACCOUNT_EMAIL)' unless email
      raise ArgumentError, 'password required (via argument or MASSIVE_ACCOUNT_PASSWORD)' unless password

      client = sign_in(email: email, password: password)
      raise Error, 'Authentication failed' unless client

      client.account_info
    end

    # Authenticates and creates a new client
    #
    # @param email [String] The user's email address
    # @param password [String] The user's password
    # @return [Client, nil] Authenticated client or nil if authentication fails
    # @raise [ArgumentError] if email or password is missing
    def self.sign_in(email:, password:)
      Client.sign_in(email: email, password: password)
    end

    # Creates a client with existing credentials
    #
    # @param account_id [String] The account UUID
    # @param token [String] The session token
    # @return [Client] New client instance
    def self.new(account_id:, token:)
      Client.new(account_id: account_id, token: token)
    end
  end
end
