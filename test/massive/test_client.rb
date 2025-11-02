require "test_helper"

class TestMassiveAccountClient < Minitest::Test
  def setup
    @account_id = "test-account-id"
    @token = "test-token"
    @client = Massive::Account::Client.new(account_id: @account_id, token: @token)
  end

  # ============================================================================
  # Client Creation Tests
  # ============================================================================

  def test_new_creates_client_with_credentials
    client = Massive::Account::Client.new(account_id: "test-id", token: "test-token")
    assert_equal "test-id", client.account_id
    assert_equal "test-token", client.token
  end

  def test_sign_in_requires_email
    error = assert_raises(ArgumentError) do
      Massive::Account::Client.sign_in(email: nil, password: "password")
    end
    assert_match(/email is required/, error.message)
  end

  def test_sign_in_requires_password
    error = assert_raises(ArgumentError) do
      Massive::Account::Client.sign_in(email: "test@example.com", password: "")
    end
    assert_match(/password is required/, error.message)
  end

  # ============================================================================
  # Account Info Tests (API-First)
  # ============================================================================

  def test_account_info_returns_complete_structure
    # Mock API response
    api_data = {
      email: "test@example.com",
      subscription_id: "sub_123",
      provider: "polygon",
      billing_interval: "month",
      account_type: "user",
      email_verified: true,
      created_utc: "2022-01-01T00:00:00.000Z",
      updated_utc: "2023-01-01T00:00:00.000Z",
      payment_id: "cus_123",
      max_websocket_connections_by_asset_type: {
        stocks: 1
      },
      rate_limit_by_asset_type: {
        currencies: 5,
        indices: 5,
        options: 5
      }
    }

    Massive::Account::API.stub :fetch_account, api_data do
      Massive::Account::Keys.stub :fetch, [] do
        info = @client.account_info

        # Top-level account metadata
        assert_equal @account_id, info[:account_id]
        assert_equal "test@example.com", info[:email]
        assert_equal "sub_123", info[:subscription_id]
        assert_equal "polygon", info[:provider]
        assert_equal "month", info[:billing_interval]
        assert_equal "user", info[:account_type]
        assert_equal true, info[:email_verified]
        assert_equal "2022-01-01T00:00:00.000Z", info[:created_utc]
        assert_equal "2023-01-01T00:00:00.000Z", info[:updated_utc]
        assert_equal "cus_123", info[:payment_id]

        # Asset classes (union of websocket and rate_limit keys, sorted)
        assert_equal [:currencies, :indices, :options, :stocks], info[:asset_classes]

        # Assets configuration
        assert_equal 4, info[:assets].size

        # Stocks: has websocket, no rate limit in API (so unlimited)
        assert_equal 1, info[:assets][:stocks][:websocket_connection_limit]
        assert_equal 99, info[:assets][:stocks][:rest_rate_limit][:requests]
        assert_equal 1, info[:assets][:stocks][:rest_rate_limit][:window]

        # Currencies: no websocket, has rate limit
        assert_equal 0, info[:assets][:currencies][:websocket_connection_limit]
        assert_equal 5, info[:assets][:currencies][:rest_rate_limit][:requests]
        assert_equal 60, info[:assets][:currencies][:rest_rate_limit][:window]
      end
    end
  end

  def test_account_info_is_memoized
    api_data = {
      max_websocket_connections_by_asset_type: {},
      rate_limit_by_asset_type: { stocks: 5 }
    }

    call_count = 0
    fetch_stub = lambda do |*args|
      call_count += 1
      api_data
    end

    Massive::Account::API.stub :fetch_account, fetch_stub do
      Massive::Account::Keys.stub :fetch, [] do
        @client.account_info
        @client.account_info
        @client.account_info

        assert_equal 1, call_count, "API should only be called once (memoized)"
      end
    end
  end

  # ============================================================================
  # Asset Classes Tests
  # ============================================================================

  def test_asset_classes_returns_sorted_union_of_assets
    api_data = {
      max_websocket_connections_by_asset_type: {
        stocks: 1,
        options: 1
      },
      rate_limit_by_asset_type: {
        currencies: 5,
        indices: 5,
        stocks: 10  # stocks appears in both
      }
    }

    Massive::Account::API.stub :fetch_account, api_data do
      Massive::Account::Keys.stub :fetch, [] do
        classes = @client.asset_classes

        # Should be union (no duplicates), sorted
        assert_equal [:currencies, :indices, :options, :stocks], classes
      end
    end
  end

  # ============================================================================
  # REST Rate Limit Tests
  # ============================================================================

  def test_rest_rate_limit_returns_limit_for_asset_with_api_limit
    api_data = {
      max_websocket_connections_by_asset_type: {},
      rate_limit_by_asset_type: {
        currencies: 5
      }
    }

    Massive::Account::API.stub :fetch_account, api_data do
      Massive::Account::Keys.stub :fetch, [] do
        limit = @client.rest_rate_limit(:currencies)

        assert_equal 5, limit[:requests]
        assert_equal 60, limit[:window]  # Assume per minute
      end
    end
  end

  def test_rest_rate_limit_returns_unlimited_for_asset_without_api_limit
    api_data = {
      max_websocket_connections_by_asset_type: {
        stocks: 1
      },
      rate_limit_by_asset_type: {}
    }

    Massive::Account::API.stub :fetch_account, api_data do
      Massive::Account::Keys.stub :fetch, [] do
        limit = @client.rest_rate_limit(:stocks)

        assert_equal 99, limit[:requests]
        assert_equal 1, limit[:window]  # Unlimited = 99/sec
      end
    end
  end

  def test_rest_rate_limit_returns_nil_for_unknown_asset
    api_data = {
      max_websocket_connections_by_asset_type: {},
      rate_limit_by_asset_type: {}
    }

    Massive::Account::API.stub :fetch_account, api_data do
      Massive::Account::Keys.stub :fetch, [] do
        assert_nil @client.rest_rate_limit(:futures)
      end
    end
  end

  def test_rest_rate_limits_returns_all_limits
    api_data = {
      max_websocket_connections_by_asset_type: {
        stocks: 1
      },
      rate_limit_by_asset_type: {
        currencies: 5,
        options: 10
      }
    }

    Massive::Account::API.stub :fetch_account, api_data do
      Massive::Account::Keys.stub :fetch, [] do
        limits = @client.rest_rate_limits

        assert_equal 3, limits.size
        assert_equal 99, limits[:stocks][:requests]
        assert_equal 5, limits[:currencies][:requests]
        assert_equal 10, limits[:options][:requests]
      end
    end
  end

  # ============================================================================
  # WebSocket Connection Limit Tests
  # ============================================================================

  def test_websocket_connection_limit_returns_value_from_api
    api_data = {
      max_websocket_connections_by_asset_type: {
        stocks: 3
      },
      rate_limit_by_asset_type: {}
    }

    Massive::Account::API.stub :fetch_account, api_data do
      Massive::Account::Keys.stub :fetch, [] do
        assert_equal 3, @client.websocket_connection_limit(:stocks)
      end
    end
  end

  def test_websocket_connection_limit_returns_zero_when_not_in_api
    api_data = {
      max_websocket_connections_by_asset_type: {},
      rate_limit_by_asset_type: {
        currencies: 5
      }
    }

    Massive::Account::API.stub :fetch_account, api_data do
      Massive::Account::Keys.stub :fetch, [] do
        assert_equal 0, @client.websocket_connection_limit(:currencies)
      end
    end
  end

  def test_websocket_connection_limit_returns_zero_for_unknown_asset
    api_data = {
      max_websocket_connections_by_asset_type: {},
      rate_limit_by_asset_type: {}
    }

    Massive::Account::API.stub :fetch_account, api_data do
      Massive::Account::Keys.stub :fetch, [] do
        assert_equal 0, @client.websocket_connection_limit(:futures)
      end
    end
  end

  # ============================================================================
  # Credential Sets Tests
  # ============================================================================

  def test_credential_sets_includes_all_keys_with_details
    api_data = {
      max_websocket_connections_by_asset_type: {},
      rate_limit_by_asset_type: {}
    }

    keys_list = [
      { id: "key-1", name: "Default", key: "api_key_1", created_at: "2024-01-01" },
      { id: "key-2", name: "Production", key: "api_key_2", created_at: "2024-01-02" }
    ]

    details_map = {
      "key-1" => {
        s3_access_key_id: "s3_access_1",
        s3_secret_access_key: "s3_secret_1",
        s3_endpoint: "https://s3.example.com",
        s3_bucket: "bucket-1"
      },
      "key-2" => {
        s3_access_key_id: "s3_access_2",
        s3_secret_access_key: "s3_secret_2",
        s3_endpoint: "https://s3.example.com",
        s3_bucket: "bucket-2"
      }
    }

    fetch_details_stub = lambda do |account_id, key_id, token:|
      details_map[key_id]
    end

    Massive::Account::API.stub :fetch_account, api_data do
      Massive::Account::Keys.stub :fetch, keys_list do
        Massive::Account::Keys.stub :fetch_key_details, fetch_details_stub do
          info = @client.account_info

          assert_equal 2, info[:credential_sets].size

          # First credential
          assert_equal "key-1", info[:credential_sets][0][:id]
          assert_equal "Default", info[:credential_sets][0][:name]
          assert_equal "api_key_1", info[:credential_sets][0][:api_key]
          assert_equal "s3_access_1", info[:credential_sets][0][:s3][:access_key_id]

          # Second credential
          assert_equal "key-2", info[:credential_sets][1][:id]
          assert_equal "Production", info[:credential_sets][1][:name]
        end
      end
    end
  end

  def test_primary_credential_set_returns_default_when_exists
    api_data = {
      max_websocket_connections_by_asset_type: {},
      rate_limit_by_asset_type: {}
    }

    keys_list = [
      { id: "key-1", name: "Production", key: "api_key_1" },
      { id: "key-2", name: "Default", key: "api_key_2" },
      { id: "key-3", name: "Development", key: "api_key_3" }
    ]

    Massive::Account::API.stub :fetch_account, api_data do
      Massive::Account::Keys.stub :fetch, keys_list do
        Massive::Account::Keys.stub :fetch_key_details, {} do
          primary = @client.primary_credential_set

          assert_equal "key-2", primary[:id]
          assert_equal "Default", primary[:name]
        end
      end
    end
  end

  def test_primary_credential_set_returns_last_when_no_default
    api_data = {
      max_websocket_connections_by_asset_type: {},
      rate_limit_by_asset_type: {}
    }

    keys_list = [
      { id: "key-1", name: "Production", key: "api_key_1" },
      { id: "key-2", name: "Development", key: "api_key_2" },
      { id: "key-3", name: "Staging", key: "api_key_3" }
    ]

    Massive::Account::API.stub :fetch_account, api_data do
      Massive::Account::Keys.stub :fetch, keys_list do
        Massive::Account::Keys.stub :fetch_key_details, {} do
          primary = @client.primary_credential_set

          assert_equal "key-3", primary[:id]
          assert_equal "Staging", primary[:name]
        end
      end
    end
  end

  def test_primary_credential_set_returns_nil_when_no_credentials
    api_data = {
      max_websocket_connections_by_asset_type: {},
      rate_limit_by_asset_type: {}
    }

    Massive::Account::API.stub :fetch_account, api_data do
      Massive::Account::Keys.stub :fetch, [] do
        assert_nil @client.primary_credential_set
      end
    end
  end
end
