require "test_helper"

class TestMassiveAccountClient < Minitest::Test
  def test_login_returns_client_on_success
    # Mock successful authentication
    credentials = { account_id: "test-id-123", token: "test-token-456" }

    Massive::Account::Authentication.stub :authenticate, credentials do
      client = Massive::Account.sign_in(email: "test@example.com", password: "password")

      assert_instance_of Massive::Account::Client, client
      assert_equal "test-id-123", client.account_id
      assert_equal "test-token-456", client.token
    end
  end

  def test_login_returns_nil_on_failure
    # Mock failed authentication
    Massive::Account::Authentication.stub :authenticate, nil do
      client = Massive::Account.sign_in(email: "bad@example.com", password: "wrong")

      assert_nil client
    end
  end

  def test_login_requires_email
    assert_raises(ArgumentError) do
      Massive::Account.sign_in(email: nil, password: "password")
    end

    assert_raises(ArgumentError) do
      Massive::Account.sign_in(email: "", password: "password")
    end
  end

  def test_login_requires_password
    assert_raises(ArgumentError) do
      Massive::Account.sign_in(email: "test@example.com", password: nil)
    end

    assert_raises(ArgumentError) do
      Massive::Account.sign_in(email: "test@example.com", password: "")
    end
  end

  def test_new_creates_client_with_credentials
    client = Massive::Account.new(
      account_id: "test-id",
      token: "test-token",
    )

    assert_instance_of Massive::Account::Client, client
    assert_equal "test-id", client.account_id
    assert_equal "test-token", client.token
  end

  def test_info_uses_env_variables
    # Mock ENV
    original_email = ENV['MASSIVE_ACCOUNT_EMAIL']
    original_password = ENV['MASSIVE_ACCOUNT_PASSWORD']

    ENV['MASSIVE_ACCOUNT_EMAIL'] = 'test@example.com'
    ENV['MASSIVE_ACCOUNT_PASSWORD'] = 'test_password'

    credentials = { account_id: "test-id", token: "test-token" }
    raw_resources = { "stocks" => { plan: "Stocks Starter", features: { "api_calls" => "Unlimited API Calls" } } }

    Massive::Account::Authentication.stub :authenticate, credentials do
      Massive::Account::Resources.stub :fetch, raw_resources do
        Massive::Account::Keys.stub :fetch, [] do
          info = Massive::Account.info

          assert_equal "test-id", info[:account_id]
          assert_equal "starter", info.dig(:resources, :stocks, :tier)
        end
      end
    end
  ensure
    ENV['MASSIVE_ACCOUNT_EMAIL'] = original_email
    ENV['MASSIVE_ACCOUNT_PASSWORD'] = original_password
  end

  def test_info_accepts_explicit_credentials
    credentials = { account_id: "test-id", token: "test-token" }
    raw_resources = { "stocks" => { plan: "Stocks Starter", features: {} } }

    Massive::Account::Authentication.stub :authenticate, credentials do
      Massive::Account::Resources.stub :fetch, raw_resources do
        Massive::Account::Keys.stub :fetch, [] do
          info = Massive::Account.info(email: "override@example.com", password: "override_pass")

          assert_equal "test-id", info[:account_id]
        end
      end
    end
  end

  def test_client_resources
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    expected_resources = {
      stocks: { plan: "Stocks Starter", features: {} },
    }

    Massive::Account::Resources.stub :fetch, expected_resources do
      resources = client.resources
      assert_equal expected_resources, resources
    end
  end

  def test_client_keys
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    expected_keys = [
      { name: "test-key", key: "abc123", id: "key-id-1" },
    ]

    Massive::Account::Keys.stub :fetch, expected_keys do
      keys = client.keys
      assert_equal expected_keys, keys
    end
  end

  def test_client_key_details
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    expected_details = {
      name: "test-key",
      api_key: "abc123",
      s3_access_key_id: "AKIATEST",
      s3_secret_access_key: "secret123",
    }

    Massive::Account::Keys.stub :fetch_key_details, expected_details do
      details = client.key_details("key-id-1")
      assert_equal expected_details, details
    end
  end

  def test_account_info_fetches_comprehensive_data
    client = Massive::Account::Client.new(
      account_id: "test-account-123",
      token: "test-token-456",
    )

    raw_resources = {
      "stocks" => {
        plan: "Stocks Developer",
        features: {
          "api_calls" => "Unlimited API Calls",
          "historical_data" => "10 Years Historical Data",
          "timeframe" => "Real-time Data",
          "websocket" => "available",
          "snapshot" => "available",
          "second_aggregates" => "available",
          "flat_files" => "available",
          "trades" => "available",
        },
      },
      "options" => {
        plan: "Options Basic",
        features: {
          "api_calls" => "5 API Calls / Minute",
          "historical_data" => "2 Years Historical Data",
          "timeframe" => "End of Day Data",
        },
      },
    }

    expected_keys = [
      { id: "key-1", name: "Production", key: "massive_prod_key", created_at: "2024-01-01" },
      { id: "key-2", name: "Development", key: "massive_dev_key", created_at: "2024-01-02" },
    ]

    key1_details = {
      s3_access_key_id: "AKIA_PROD",
      s3_secret_access_key: "secret_prod",
      s3_endpoint: "s3.amazonaws.com",
      s3_bucket: "massive-prod",
    }

    key2_details = {
      s3_access_key_id: "AKIA_DEV",
      s3_secret_access_key: "secret_dev",
      s3_endpoint: "s3.amazonaws.com",
      s3_bucket: "massive-dev",
    }

    Massive::Account::Resources.stub :fetch, raw_resources do
      Massive::Account::Keys.stub :fetch, expected_keys do
        Massive::Account::Keys.stub :fetch_key_details, ->(account_id, key_id, token:) {
          key_id == "key-1" ? key1_details : key2_details
        } do
          info = client.account_info

          # Check account_id
          assert_equal "test-account-123", info[:account_id]

          # Check normalized resources (all symbol keys, use dig)
          assert_equal "developer", info.dig(:resources, :stocks, :tier)
          assert_equal 10, info.dig(:resources, :stocks, :historical_years)
          assert_equal 99, info.dig(:resources, :stocks, :rate_limit, :requests)
          assert_equal true, info.dig(:resources, :stocks, :realtime)
          assert_equal 0, info.dig(:resources, :stocks, :delay_minutes)
          assert_equal true, info.dig(:resources, :stocks, :websocket)
          assert_equal true, info.dig(:resources, :stocks, :features, :trades)
          assert_equal true, info.dig(:resources, :stocks, :features, :snapshot)

          assert_equal "basic", info.dig(:resources, :options, :tier)
          assert_equal 2, info.dig(:resources, :options, :historical_years)
          assert_equal 5, info.dig(:resources, :options, :rate_limit, :requests)
          assert_equal false, info.dig(:resources, :options, :realtime)
          assert_equal 0, info.dig(:resources, :options, :delay_minutes)  # EOD = 0

          # Check credential sets
          assert_equal 2, info[:credential_sets].length
          first_cred = info[:credential_sets][0]
          assert_equal "key-1", first_cred[:id]
          assert_equal "Production", first_cred[:name]
          assert_equal "massive_prod_key", first_cred[:api_key]
          assert_equal "AKIA_PROD", first_cred[:s3][:access_key_id]
        end
      end
    end
  end

  def test_account_info_handles_empty_credentials
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    Massive::Account::Resources.stub :fetch, {} do
      Massive::Account::Keys.stub :fetch, [] do
        info = client.account_info

        assert_equal "test-id", info[:account_id]
        assert_equal({}, info[:resources])
        assert_equal [], info[:credential_sets]
      end
    end
  end

  def test_primary_credential_set_prefers_default
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    expected_keys = [
      { id: "key-1", name: "Production", key: "massive_prod", created_at: "2024-01-01" },
      { id: "key-2", name: "Default", key: "massive_default", created_at: "2023-01-01" },
    ]

    key_details_prod = {
      s3_access_key_id: "AKIA_PROD",
      s3_secret_access_key: "secret_prod",
      s3_endpoint: "s3.amazonaws.com",
      s3_bucket: "massive-prod",
    }

    key_details_default = {
      s3_access_key_id: "AKIA_DEFAULT",
      s3_secret_access_key: "secret_default",
      s3_endpoint: "s3.amazonaws.com",
      s3_bucket: "massive-default",
    }

    Massive::Account::Resources.stub :fetch, {} do
      Massive::Account::Keys.stub :fetch, expected_keys do
        Massive::Account::Keys.stub :fetch_key_details, ->(account_id, key_id, token:) {
          key_id == "key-1" ? key_details_prod : key_details_default
        } do
          primary = client.primary_credential_set

          # Should return "Default", not first one
          assert_equal "key-2", primary[:id]
          assert_equal "Default", primary[:name]
          assert_equal "massive_default", primary[:api_key]
        end
      end
    end
  end

  def test_primary_credential_set_returns_last_when_no_default
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    expected_keys = [
      { id: "key-1", name: "harpy_4", key: "massive_key_1", created_at: "2024-01-01" },
      { id: "key-2", name: "harpy_3", key: "massive_key_2", created_at: "2023-01-01" },
    ]

    key_details = {
      s3_access_key_id: "AKIA_KEY2",
      s3_secret_access_key: "secret_key2",
      s3_endpoint: "s3.amazonaws.com",
      s3_bucket: "massive-bucket",
    }

    Massive::Account::Resources.stub :fetch, {} do
      Massive::Account::Keys.stub :fetch, expected_keys do
        Massive::Account::Keys.stub :fetch_key_details, key_details do
          primary = client.primary_credential_set

          # Should return last (oldest)
          assert_equal "key-2", primary[:id]
          assert_equal "harpy_3", primary[:name]
        end
      end
    end
  end

  def test_primary_credential_set_returns_nil_when_no_credentials
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    Massive::Account::Resources.stub :fetch, {} do
      Massive::Account::Keys.stub :fetch, [] do
        primary = client.primary_credential_set

        assert_nil primary
      end
    end
  end

  def test_rate_limit_parses_unlimited_as_99_per_second
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => {
        plan: "Stocks Starter",
        features: { "api_calls" => "Unlimited API Calls" },
      },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        limit = client.rate_limit(:stocks)

        assert_equal 99, limit[:requests]
        assert_equal 1, limit[:window]
      end
    end
  end

  def test_rate_limit_parses_calls_per_minute
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "options" => {
        plan: "Options Basic",
        features: { "api_calls" => "5 API Calls / Minute" },
      },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        limit = client.rate_limit(:options)

        assert_equal 5, limit[:requests]
        assert_equal 60, limit[:window]
      end
    end
  end

  def test_rate_limit_parses_calls_per_second
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => {
        plan: "Stocks Professional",
        features: { "api_calls" => "75 API Calls / Second" },
      },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        limit = client.rate_limit(:stocks)

        assert_equal 75, limit[:requests]
        assert_equal 1, limit[:window]
      end
    end
  end

  def test_rate_limit_accepts_string_or_symbol
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => {
        plan: "Stocks Professional",
        features: { "api_calls" => "33 API Calls / Minute" },
      },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        limit_symbol = client.rate_limit(:stocks)
        limit_string = client.rate_limit("stocks")

        assert_equal limit_symbol, limit_string
        assert_equal 33, limit_symbol[:requests]
        assert_equal 60, limit_symbol[:window]
      end
    end
  end

  def test_rate_limit_returns_nil_for_unknown_resource
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    Massive::Account::Resources.stub :fetch, {} do
      Massive::Account::Keys.stub :fetch, [] do
        limit = client.rate_limit(:unknown)

        assert_nil limit
      end
    end
  end

  def test_rate_limits_returns_all_rate_limits
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => {
        plan: "Stocks Starter",
        features: { "api_calls" => "Unlimited API Calls" },
      },
      "options" => {
        plan: "Options Basic",
        features: { "api_calls" => "5 API Calls / Minute" },
      },
      "currencies" => {
        plan: "Currencies Pro",
        features: { "api_calls" => "17 API Calls / Minute" },
      },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        limits = client.rate_limits

        assert_equal 3, limits.size

        assert_equal 99, limits.dig(:stocks, :requests)
        assert_equal 1, limits.dig(:stocks, :window)

        assert_equal 5, limits.dig(:options, :requests)
        assert_equal 60, limits.dig(:options, :window)

        assert_equal 17, limits.dig(:currencies, :requests)
        assert_equal 60, limits.dig(:currencies, :window)

      end
    end
  end

  def test_rate_limits_handles_missing_rate_limit_data
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => {
        plan: "Stocks Professional",
        features: { "realtime" => "true" },  # No api_calls info
      },
      "options" => {
        plan: "Options Basic",
        features: { "api_calls" => "10 API Calls / Second" },
      },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        limits = client.rate_limits

        # stocks should be excluded (no api_calls)
        assert_equal 1, limits.size
        assert_nil limits[:stocks]

        # options should be present
        assert_equal 10, limits.dig(:options, :requests)
      end
    end
  end

  def test_historical_years_parses_years_correctly
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => {
        plan: "Stocks Starter",
        features: { "historical_data" => "5 Years Historical Data" },
      },
      "options" => {
        plan: "Options Basic",
        features: { "historical_data" => "2 Years Historical Data" },
      },
      "indices" => {
        plan: "Indices Basic",
        features: { "historical_data" => "1+ Year Historical Data" },
      },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        assert_equal 5, client.historical_years(:stocks)
        assert_equal 2, client.historical_years(:options)
        assert_equal 1, client.historical_years(:indices)
      end
    end
  end

  def test_historical_years_returns_nil_when_not_available
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => {
        plan: "Stocks Starter",
        features: { "timeframe" => "Real-time Data" },
      },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        assert_nil client.historical_years(:stocks)
        assert_nil client.historical_years(:unknown)
      end
    end
  end

  def test_realtime_detects_delayed_data
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => {
        plan: "Stocks Starter",
        features: { "timeframe" => "15-minute Delayed Data" },
      },
      "options" => {
        plan: "Options Basic",
        features: { "timeframe" => "End of Day Data" },
      },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        assert_equal false, client.realtime?(:stocks)
        assert_equal false, client.realtime?(:options)
      end
    end
  end

  def test_realtime_detects_realtime_data
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => {
        plan: "Stocks Professional",
        features: { "timeframe" => "Real-time Data" },
      },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        assert_equal true, client.realtime?(:stocks)
      end
    end
  end

  def test_websocket_detects_availability
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => {
        plan: "Stocks Starter",
        features: { "websocket" => "available" },
      },
      "options" => {
        plan: "Options Basic",
        features: { "timeframe" => "End of Day Data" },
      },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        assert_equal true, client.websocket?(:stocks)
        assert_equal false, client.websocket?(:options)
        assert_equal false, client.websocket?(:unknown)
      end
    end
  end

  def test_normalized_resource_structure
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    raw_resources = {
      "stocks" => {
        plan: "Stocks Starter",
        features: {
          "historical_data" => "5 Years Historical Data",
          "timeframe" => "15-minute Delayed Data",
          "websocket" => "available",
          "api_calls" => "Unlimited API Calls",
          "snapshot" => "available",
          "second_aggregates" => "available",
          "flat_files" => "available",
        },
      },
    }

    Massive::Account::Resources.stub :fetch, raw_resources do
      Massive::Account::Keys.stub :fetch, [] do
        resource = client.account_info[:resources][:stocks]  # Symbol key

        # Check normalized structure
        assert_equal "starter", resource[:tier]
        assert_equal 5, resource[:historical_years]
        assert_equal 99, resource[:rate_limit][:requests]
        assert_equal 1, resource[:rate_limit][:window]
        assert_equal false, resource[:realtime]
        assert_equal 15, resource[:delay_minutes]
        assert_equal true, resource[:websocket]
        assert_equal true, resource[:features][:snapshot]
        assert_equal true, resource[:features][:second_aggregates]
        assert_equal true, resource[:features][:flat_files]
      end
    end
  end

  def test_historical_cutoff_date_calculates_correctly
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => {
        plan: "Stocks Starter",
        features: { "historical_data" => "2 Years Historical Data" },
      },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        cutoff = client.historical_cutoff_date(:stocks)
        # Server uses simple day arithmetic (matches actual implementation)
        expected = Date.today - (2 * 365)

        assert_equal expected, cutoff
      end
    end
  end

  def test_historical_cutoff_time_calculates_correctly
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => {
        plan: "Stocks Starter",
        features: { "historical_data" => "5 Years Historical Data" },
      },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        cutoff = client.historical_cutoff_time(:stocks)
        # Server uses simple seconds arithmetic
        expected = Time.now - (5 * 365 * 24 * 60 * 60)

        # Allow 1 second tolerance for test execution time
        assert_in_delta expected.to_i, cutoff.to_i, 1
      end
    end
  end

  def test_historical_cutoff_returns_nil_when_no_data
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    Massive::Account::Resources.stub :fetch, {} do
      Massive::Account::Keys.stub :fetch, [] do
        assert_nil client.historical_cutoff_date(:unknown)
        assert_nil client.historical_cutoff_time(:unknown)
      end
    end
  end

  def test_tier_extracts_tier_from_plan_name
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => { plan: "Stocks Starter", features: {} },
      "options" => { plan: "Options Basic", features: {} },
      "currencies" => { plan: "Currencies Developer", features: {} },
      "indices" => { plan: "Indices Advanced", features: {} },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        assert_equal "starter", client.tier(:stocks)
        assert_equal "basic", client.tier(:options)
        assert_equal "developer", client.tier(:currencies)
        assert_equal "advanced", client.tier(:indices)
      end
    end
  end

  def test_tier_handles_case_insensitive
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => { plan: "Stocks STARTER", features: {} },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        assert_equal "starter", client.tier(:stocks)
      end
    end
  end

  def test_tier_returns_nil_for_unknown_resource
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    Massive::Account::Resources.stub :fetch, {} do
      Massive::Account::Keys.stub :fetch, [] do
        assert_nil client.tier(:unknown)
      end
    end
  end

  def test_tiers_returns_all_tiers
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => { plan: "Stocks Starter", features: {} },
      "options" => { plan: "Options Basic", features: {} },
      "currencies" => { plan: "Currencies Developer", features: {} },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        tiers = client.tiers

        assert_equal 3, tiers.size
        assert_equal "starter", tiers[:stocks]
        assert_equal "basic", tiers[:options]
        assert_equal "developer", tiers[:currencies]
      end
    end
  end

  def test_paid_returns_false_for_all_basic_tier
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => { plan: "Stocks Basic", features: {} },
      "options" => { plan: "Options Basic", features: {} },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        info = client.account_info

        assert_equal false, info[:paid]
      end
    end
  end

  def test_paid_returns_true_for_starter_tier
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => { plan: "Stocks Starter", features: {} },
      "options" => { plan: "Options Basic", features: {} },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        info = client.account_info

        assert_equal true, info[:paid]
      end
    end
  end

  def test_paid_returns_true_for_developer_tier
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => { plan: "Stocks Developer", features: {} },
      "options" => { plan: "Options Basic", features: {} },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        info = client.account_info

        assert_equal true, info[:paid]
      end
    end
  end

  def test_paid_returns_true_for_advanced_tier
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    resources = {
      "stocks" => { plan: "Stocks Advanced", features: {} },
      "options" => { plan: "Options Basic", features: {} },
    }

    Massive::Account::Resources.stub :fetch, resources do
      Massive::Account::Keys.stub :fetch, [] do
        info = client.account_info

        assert_equal true, info[:paid]
      end
    end
  end

  def test_paid_returns_false_for_no_resources
    client = Massive::Account::Client.new(
      account_id: "test-id",
      token: "test-token",
    )

    Massive::Account::Resources.stub :fetch, {} do
      Massive::Account::Keys.stub :fetch, [] do
        info = client.account_info

        assert_equal false, info[:paid]
      end
    end
  end
end
