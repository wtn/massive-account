# API Reference

Complete API documentation for the `massive-account` gem.

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
  account_id: "0400c033-2fcc-48b6-be65-c5c6c8c8b24b",
  token: "e50a6d284cf213b210b3271b7eb50dc3"
)
```

## Account Information

### `#account_info`

Fetch comprehensive account information (subscriptions, credentials, features).

**Returns:** Hash with structure:
```ruby
{
  account_id: String,
  resources: Hash[String, { plan: String, features: Hash[String, String] }],
  credentials: Array[{
    id: String?,
    name: String?,
    api_key: String,
    created_at: String?,
    s3: {
      access_key_id: String,
      secret_access_key: String,
      endpoint: String,
      bucket: String
    }
  }]
}
```

**Note:** Results are memoized (cached) after first call.

**Example:**
```ruby
info = client.account_info
info[:account_id]                    # => "0400c033-2fcc-48b6..."
info[:resources]["stocks"][:plan]    # => "Stocks Starter"
info[:credential_sets].first[:api_key]   # => "mUzEWsXhurbB5PcsJxX5WgUthlJKPDmt"
```

## Subscription Tiers

### `#tier(resource)`

Get the subscription tier for a specific resource.

**Parameters:**
- `resource` (String | Symbol) - Resource name: `:stocks`, `:options`, `:futures`, `:indices`, `:currencies`

**Returns:** String (`"basic"`, `"starter"`, `"developer"`, `"advanced"`) or `nil`

**Example:**
```ruby
client.tier(:stocks)      # => "starter"
client.tier("options")    # => "basic"
```

### `#tiers`

Get all subscription tiers.

**Returns:** Hash mapping resource names to tier names

**Example:**
```ruby
client.tiers
# => { "stocks" => "starter", "options" => "basic", "currencies" => "basic" }
```

## Credentials

### `#primary_credential_set`

Get the first (primary) credential set.

**Returns:** Hash or `nil` if no credentials exist

**Example:**
```ruby
creds = client.primary_credential_set
creds[:api_key]                        # For REST/WebSocket
creds[:s3][:access_key_id]            # For S3
creds[:s3][:endpoint]                 # => "https://files.massive.com"
```

## Rate Limits

### `#rate_limit(resource)`

Get rate limit for a specific resource (window-based).

**Parameters:**
- `resource` (String | Symbol) - Resource name

**Returns:** Hash `{ requests: Integer, window: Integer }` or `nil` if not found

**Important:** "Unlimited API Calls" is translated to `{ requests: 99, window: 1 }` (the actual server limit).

**Example:**
```ruby
limit = client.rate_limit(:stocks)
# => { requests: 99, window: 1 }      # "Unlimited API Calls" → 99/sec
# => { requests: 5, window: 60 }      # "5 API Calls / Minute"
```

### `#rate_limits`

Get rate limits for all resources.

**Returns:** Hash mapping resource names to rate limit hashes

**Important:** "Unlimited API Calls" is translated to `{ requests: 99, window: 1 }`.

**Example:**
```ruby
limits = client.rate_limits
# => {
#   "stocks" => { requests: 99, window: 1 },      # "Unlimited" → 99/sec
#   "options" => { requests: 5, window: 60 },     # 5/min
#   "currencies" => { requests: 5, window: 60 }   # 5/min
# }
```

## Historical Data

### `#historical_years(resource)`

Get years of historical data available.

**Parameters:**
- `resource` (String | Symbol) - Resource name

**Returns:** Integer or `nil`

**Example:**
```ruby
client.historical_years(:stocks)   # => 5
client.historical_years(:options)  # => 2
```

### `#historical_cutoff_date(resource)`

Get earliest date for historical data (conservative estimate).

**Parameters:**
- `resource` (String | Symbol) - Resource name

**Returns:** Date or `nil`

**Note:** Uses advertised period (e.g., "2 Years" → 730 days ago), not actual server limit.

**Example:**
```ruby
cutoff = client.historical_cutoff_date(:stocks)
# => #<Date: 2020-11-03>

# Use in API queries
from_date = cutoff
to_date = Date.today
```

### `#historical_cutoff_time(resource)`

Get earliest time for historical data (conservative estimate).

**Parameters:**
- `resource` (String | Symbol) - Resource name

**Returns:** Time or `nil`

**Example:**
```ruby
cutoff = client.historical_cutoff_time(:stocks)
# => 2020-11-03 12:30:15 -0600
```

## Data Freshness

### `#realtime?(resource)`

Check if resource has real-time (non-delayed) data.

**Parameters:**
- `resource` (String | Symbol) - Resource name

**Returns:** Boolean

**Example:**
```ruby
client.realtime?(:stocks)   # => false (15-minute delayed)
client.realtime?(:options)  # => false (end of day)
```

## WebSocket Access

### `#websocket?(resource)`

Check if resource has WebSocket access.

**Parameters:**
- `resource` (String | Symbol) - Resource name

**Returns:** Boolean

**Example:**
```ruby
client.websocket?(:stocks)   # => true
client.websocket?(:options)  # => false
```

## Feature Summary

### `#features(resource)`

Get comprehensive feature summary for a resource.

**Parameters:**
- `resource` (String | Symbol) - Resource name

**Returns:** Hash or `nil`

**Example:**
```ruby
features = client.features(:stocks)
# => {
#   historical_years: 5,
#   realtime: false,
#   websocket: true,
#   rate_limit: nil
# }
```

## Low-Level Methods

### `#resources`

Fetch raw subscription data (not cached).

**Returns:** Hash of resources by category

**Example:**
```ruby
resources = client.resources
# => { "stocks" => { plan: "Stocks Starter", features: {...} } }
```

### `#keys`

Fetch all API keys (not cached).

**Returns:** Array of key hashes

**Example:**
```ruby
keys = client.keys
# => [{ id: "498d599f-cf4c-4551-bf1c-66f8cdeacc63", name: "example_1", key: "mUzEW...", created_at: nil }]
```

### `#key_details(key_id)`

Fetch detailed information for a specific key (not cached).

**Parameters:**
- `key_id` (String) - Key UUID

**Returns:** Hash with S3 credentials or `nil`

**Example:**
```ruby
details = client.key_details("498d599f-cf4c-4551-bf1c-66f8cdeacc63")
# => {
#   name: "example_1",
#   api_key: "mUzEWsXhurbB5PcsJxX5WgUthlJKPDmt",
#   s3_access_key_id: "498d599f-cf4c-4551-bf1c-66f8cdeacc63",
#   s3_secret_access_key: "mUzEWsXhurbB5PcsJxX5WgUthlJKPDmt",
#   s3_endpoint: "https://files.massive.com",
#   s3_bucket: "flatfiles"
# }
```

## Data Model

### Resource Structure (Normalized)

All human-readable strings are parsed into usable values:

```ruby
{
  tier: String?,                              # "basic" | "starter" | "developer" | "advanced"
  historical_years: Integer?,                 # 1, 2, 5, 10, 20
  rate_limit: { requests: Integer, window: Integer }?,  # { requests: 99, window: 1 }
  realtime: Boolean,                          # true for real-time, false for delayed/EOD
  delay_minutes: Integer?,                    # 15 for delayed, 0 for realtime, nil for EOD
  websocket: Boolean,                         # WebSocket availability
  features: {                                 # Tier-specific features (only if available)
    flat_files: true?,
    snapshot: true?,
    second_aggregates: true?,
    trades: true?,
    quotes: true?,
    financials: true?
  }?
}
```

**Example:**
```ruby
stocks = client.account_info.dig(:resources, :stocks)
# => {
#   tier: "starter",
#   historical_years: 5,
#   rate_limit: { requests: 99, window: 1 },
#   realtime: false,
#   delay_minutes: 15,
#   websocket: true,
#   features: { flat_files: true, snapshot: true, second_aggregates: true }
# }

# Access nested values safely
client.account_info.dig(:resources, :stocks, :rate_limit, :requests)  # => 99
```

**Note:** All tiers include reference_data, corporate_actions, technical_indicators, and minute_aggregates - these are not listed in `features` since they're universal.

### Credential Set Structure

```ruby
{
  id: String?,              # Key UUID
  name: String?,            # "Production", "Default", "example_1", etc.
  api_key: String,          # For REST/WebSocket
  created_at: String?,      # Creation timestamp (may be nil)
  s3: {
    access_key_id: String,
    secret_access_key: String,
    endpoint: String,       # "https://files.massive.com"
    bucket: String          # "flatfiles"
  }
}
```

### Tier Values

- `"basic"` - Free tier (limited features)
- `"starter"` - Entry paid tier
- `"developer"` - Mid-tier (includes trades)
- `"advanced"` - Full tier (includes trades + quotes)

### Rate Limit Structure

```ruby
{
  requests: Integer,  # Max requests
  window: Integer     # Window in seconds
}

# Examples:
{ requests: 100, window: 1 }    # 100 requests per 1 second
{ requests: 5, window: 60 }     # 5 requests per 60 seconds
```

## Thread Safety

**Not thread-safe.** Create separate client instances per thread or use a mutex.

## Caching

- `#account_info` - Cached after first call (memoized)
- `#resources`, `#keys`, `#key_details` - Not cached, fetches fresh data each call
- All helper methods (`#tier`, `#rate_limit`, etc.) - Use cached `#account_info`
