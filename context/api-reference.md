# API Reference

Complete API documentation for the `massive-account` gem (API-first design).

## Client Creation

### `Massive::Account.sign_in(email:, password:)`

Authenticate with massive.com and create a new client.

**Parameters:**
- `email` (String) - Your massive.com email
- `password` (String) - Your massive.com password

**Returns:** `Client` or `nil` if authentication fails

**Raises:** `ArgumentError` if email or password is missing

**Example:**
```ruby
client = Massive::Account.sign_in(
  email: "user@example.com",
  password: "password123"
)
```

### `Massive::Account.new(account_id:, token:)`

Create a client with existing credentials (skips authentication).

**Parameters:**
- `account_id` (String) - Account UUID
- `token` (String) - Session token

**Returns:** `Client`

**Example:**
```ruby
client = Massive::Account.new(
  account_id: "6d26daa4-675d-452d-b693-8dfbb5086095",
  token: "ZbuDzWhZZopO1AATLzPp5..."
)
```

### `Massive::Account.info(email:, password:)`

Convenience method to get account info without creating a client.

**Parameters:**
- `email` (String, optional) - Defaults to `ENV['MASSIVE_ACCOUNT_EMAIL']`
- `password` (String, optional) - Defaults to `ENV['MASSIVE_ACCOUNT_PASSWORD']`

**Returns:** Hash (same as `Client#account_info`)

**Example:**
```ruby
# Using ENV variables
info = Massive::Account.info

# Or pass explicitly
info = Massive::Account.info(email: "user@example.com", password: "pass")
```

## Account Information

### `#account_info`

Fetch comprehensive account information from Polygon API.

**Returns:** Hash with structure:
```ruby
{
  # Account metadata (from Polygon API)
  account_id: "6d26daa4-675d-452d-b693-8dfbb5086095",
  email: "user@example.com",
  subscription_id: "sub_1MEj2iJIoTwtcYISKsetGiwa",
  provider: "polygon",
  billing_interval: "month",
  account_type: "user",
  email_verified: false,
  created_utc: "2022-12-14T00:41:50.212Z",
  updated_utc: "2025-08-07T06:14:50.754Z",
  payment_id: "cus_MygP3R0ZCqnfv3",

  # Asset classes (derived from API)
  asset_classes: [:currencies, :indices, :options, :stocks],

  # Per-asset configuration
  assets: {
    stocks: {
      websocket_connection_limit: 1,
      rest_rate_limit: { requests: 99, window: 1 }
    },
    currencies: {
      websocket_connection_limit: 0,
      rest_rate_limit: { requests: 5, window: 60 }
    },
    # ... other asset classes
  },

  # Credential sets (from dashboard scraping)
  credential_sets: [
    {
      id: "cb2beb95-4cab-4136-bd4b-70b227e5522b",
      name: "Default",
      api_key: "6dZ7lCxHIcBb2TBY0HVm_...",
      created_at: "2024-01-01",
      s3: {
        access_key_id: "cb2beb95-4cab-4136-bd4b-70b227e5522b",
        secret_access_key: "6dZ7lCxHIcBb2TBY0HVm_...",
        endpoint: "https://files.massive.com",
        bucket: "flatfiles"
      }
    }
  ]
}
```

**Note:** Results are memoized (cached) after first call.

**Example:**
```ruby
info = client.account_info
info[:account_id]                         # => "6d26daa4-675d-452d-b693-8dfbb5086095"
info[:assets][:stocks][:rest_rate_limit]  # => { requests: 99, window: 1 }
info[:credential_sets].first[:api_key]    # => "6dZ7lCxHIcBb2TBY0HVm_..."
```

## Asset Classes

### `#asset_classes`

Get all asset classes supported by the account.

**Returns:** Array of Symbol - sorted asset class symbols

**Example:**
```ruby
client.asset_classes  # => [:currencies, :indices, :options, :stocks]
```

## REST Rate Limits

### `#rest_rate_limit(asset_class)`

Get REST API rate limit for a specific asset class.

**Parameters:**
- `asset_class` (String | Symbol) - Asset class name: `:stocks`, `:options`, `:currencies`, `:indices`

**Returns:** Hash `{ requests: Integer, window: Integer }` or `nil` if not found

**Important:** Assets not in `rate_limit_by_asset_type` are treated as unlimited (99 req/sec).

**Example:**
```ruby
client.rest_rate_limit(:stocks)      # => { requests: 99, window: 1 }  # Unlimited
client.rest_rate_limit(:currencies)  # => { requests: 5, window: 60 }  # 5/minute
client.rest_rate_limit(:futures)     # => nil (not subscribed)
```

### `#rest_rate_limits`

Get REST API rate limits for all asset classes.

**Returns:** Hash mapping asset class symbols to rate limit hashes

**Example:**
```ruby
limits = client.rest_rate_limits
# => {
#   stocks: { requests: 99, window: 1 },
#   currencies: { requests: 5, window: 60 },
#   indices: { requests: 5, window: 60 },
#   options: { requests: 5, window: 60 }
# }
```

## WebSocket Configuration

### `#websocket_connection_limit(asset_class)`

Get WebSocket connection limit for an asset class.

**Parameters:**
- `asset_class` (String | Symbol) - Asset class name

**Returns:** Integer - max concurrent connections (0 if WebSocket not available)

**Example:**
```ruby
client.websocket_connection_limit(:stocks)      # => 1
client.websocket_connection_limit(:currencies)  # => 0
client.websocket_connection_limit(:futures)     # => 0 (unknown asset)
```

## Credentials

### `#primary_credential_set`

Get the primary credential set.

**Selection Logic:**
1. Credential named "Default" (if exists)
2. Last credential in list (oldest)

**Returns:** Hash or `nil` if no credentials exist

**Example:**
```ruby
creds = client.primary_credential_set
creds[:name]                       # => "Default"
creds[:api_key]                    # => "6dZ7lCxHIcBb2TBY0HVm_..."
creds[:s3][:access_key_id]         # => "cb2beb95-4cab-4136-bd4b-70b227e5522b"
creds[:s3][:secret_access_key]     # => "6dZ7lCxHIcBb2TBY0HVm_..."
creds[:s3][:endpoint]              # => "https://files.massive.com"
creds[:s3][:bucket]                # => "flatfiles"
```

## Low-Level Methods

### `#keys`

Fetch all API keys (raw data from dashboard scraping).

**Returns:** Array of Hash - raw key data

**Example:**
```ruby
keys = client.keys
# => [
#   { id: "cb2beb95-...", name: "Default", key: "6dZ7lCxHIcBb2TBY0HVm_...", created_at: "2024-01-01" },
#   { id: "bc3deb9f-...", name: "harpy_4", key: "lHHVREvqTH8_hgXcs5eUd...", created_at: "2024-02-01" }
# ]
```

### `#key_details(key_id)`

Fetch detailed information for a specific key (including S3 credentials).

**Parameters:**
- `key_id` (String) - Key UUID

**Returns:** Hash with S3 credentials or `nil`

**Example:**
```ruby
details = client.key_details("cb2beb95-4cab-4136-bd4b-70b227e5522b")
# => {
#   s3_access_key_id: "cb2beb95-4cab-4136-bd4b-70b227e5522b",
#   s3_secret_access_key: "6dZ7lCxHIcBb2TBY0HVm_...",
#   s3_endpoint: "https://files.massive.com",
#   s3_bucket: "flatfiles"
# }
```

## Removed Methods (Not Available)

The following methods existed in previous versions but are **no longer available** because the data is not exposed in the Polygon API:

### Tier Information:
- ❌ `tier(asset_class)` - Get tier name (basic/starter/developer/advanced)
- ❌ `tiers` - Get all tiers

### Historical Data:
- ❌ `historical_years(asset_class)` - Get years of historical data
- ❌ `historical_cutoff_date(asset_class)` - Get cutoff date
- ❌ `historical_cutoff_time(asset_class)` - Get cutoff time

### Timeframe:
- ❌ `realtime?(asset_class)` - Check if real-time or delayed

If you need this information, you'll need to track it separately based on your Massive.com subscription plan.

## Data Source

All account data comes from:
```
GET https://api.polygon.io/accountservices/v1/accounts
```

With authentication via cookie:
```
Cookie: polygon-token={token}
```

The gem handles authentication, token extraction, and data normalization automatically.
