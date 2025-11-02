# Getting Started

## What This Gem Does

Fetches your massive.com account information via the **Polygon API** (`api.polygon.io`):
- Account metadata (email, subscription details)
- Asset class configuration (rate limits, WebSocket settings)
- API credentials and S3 access

**API-First Design**: Minimal scraping (only for API keys/S3 credentials which aren't in the API).

## Quickstart

**Set environment variables:**
```bash
export MASSIVE_ACCOUNT_EMAIL="your@email.com"
export MASSIVE_ACCOUNT_PASSWORD="your_password"
```

**Most common usage:**
```ruby
require 'massive/account'

# Get everything with one call (uses ENV variables)
info = Massive::Account.info

# Account metadata from Polygon API
info[:account_id]        # => "6d26daa4-675d-452d-b693-8dfbb5086095"
info[:email]             # => "your@email.com"
info[:subscription_id]   # => "sub_..."
info[:provider]          # => "polygon"
info[:billing_interval]  # => "month"
info[:account_type]      # => "user"
info[:email_verified]    # => false
info[:created_utc]       # => "2022-12-14T00:41:50.212Z"
info[:updated_utc]       # => "2025-08-07T06:14:50.754Z"

# Asset classes (derived from API data)
info[:asset_classes]     # => [:currencies, :indices, :options, :stocks]

# Per-asset configuration
info[:assets][:stocks]
# => {
#      websocket_connection_limit: 1,
#      rest_rate_limit: { requests: 99, window: 1 }  # Unlimited = 99 req/sec
#    }

info[:assets][:currencies]
# => {
#      websocket_connection_limit: 0,
#      rest_rate_limit: { requests: 5, window: 60 }  # 5 req/minute
#    }

# Get credentials
creds = info[:credential_sets].find { |c| c[:name] == "Default" }
creds[:api_key]  # For REST/WebSocket
creds[:s3]       # For S3
```

**Advanced usage (client instance):**
```ruby
client = Massive::Account.sign_in(email: "user@example.com", password: "password")

# Helper methods
client.asset_classes                       # => [:currencies, :indices, :options, :stocks]
client.rest_rate_limit(:stocks)            # => { requests: 99, window: 1 }
client.rest_rate_limits                    # => { stocks: {...}, currencies: {...}, ... }
client.websocket_connection_limit(:stocks) # => 1
client.primary_credential_set              # => { name: "Default", api_key: "...", ... }
```

See `context/api-reference.md` for complete method documentation.

## Data Source: Polygon API

This gem uses the official Polygon API endpoint:
```
https://api.polygon.io/accountservices/v1/accounts
```

### Asset Classes

Asset classes are automatically derived from the union of:
- `max_websocket_connections_by_asset_type` (assets with WebSocket access)
- `rate_limit_by_asset_type` (assets with rate limits)

### Rate Limits

**From API data:**
- If asset appears in `rate_limit_by_asset_type`: uses that value (assumed per minute, window: 60)
- If asset does NOT appear: assumes unlimited (99 requests per second, window: 1)

**Example:** Stocks typically has no rate limit in the API → treated as unlimited (99 req/sec).

### WebSocket Configuration

**From API data:**
- `max_websocket_connections_by_asset_type` provides max concurrent connections per asset
- Value is 0 or greater (0 means WebSocket not available)

## Important Behaviors

### Account Info is Memoized

First call to `account_info` makes HTTP requests and caches the result. All helper methods use this cached data.

```ruby
# Makes HTTP requests, caches result
info = client.account_info

# Uses cached data (no HTTP)
client.asset_classes
client.rest_rate_limit(:stocks)
client.websocket_connection_limit(:stocks)
```

**Why this matters**: Safe to call helpers multiple times without performance penalty.

### Primary Credential Selection

`primary_credential_set` priority order:
1. Credential named "Default" (case-insensitive)
2. Last credential in list (oldest, assuming it's the original)

```ruby
# With credentials: ["example_3", "example_2", "Default"]
client.primary_credential_set[:name]  # => "Default" (not "example_3")

# Without "Default": ["example_3", "example_2"]
client.primary_credential_set[:name]  # => "example_2" (last/oldest)
```

### Multiple Credential Sets

What Massive calls "API Keys" on their dashboard are **credential sets**, each containing:
- API key (for REST/WebSocket)
- S3 credentials (same key used as secret)

```ruby
# All keys are symbols for consistency
client.account_info[:credential_sets]
# => [{ name: "Default", api_key: "...", s3: {...} }, ...]

# Assets use symbol keys too
client.account_info[:assets][:stocks]  # => { websocket_connection_limit: 1, ... }
```

Accounts can have multiple named sets (e.g., "Production", "Development", "Default").

### S3 Credentials Use Same Key

The S3 `secret_access_key` is identical to the API key:

```ruby
creds = client.primary_credential_set
creds[:api_key]                    # "mUzEWsXhurbB5PcsJxX5WgUthlJKPDmt"
creds[:s3][:secret_access_key]     # "mUzEWsXhurbB5PcsJxX5WgUthlJKPDmt" (same!)
creds[:s3][:access_key_id]         # "498d599f-cf4c-4551-bf1c-66f8cdeacc63" (different)
```

## What's NOT in the API

The following data is **not available** from the Polygon API:

### Removed (not available):
- ❌ Tier names (basic/starter/developer/advanced)
- ❌ Historical data years
- ❌ Feature flags (flat_files, snapshot, trades, quotes, financials)
- ❌ Realtime vs delayed status
- ❌ Delay minutes

These were previously scraped from dashboard HTML but are not exposed in the official API.

### Still scraped (not in API):
- ✅ API keys list
- ✅ S3 credentials

The gem still scrapes `/dashboard/keys` because the API doesn't expose credential information.

## Troubleshooting

### Authentication Returns Nil

Massive uses CSRF tokens from the login page form. If authentication fails:
- Check credentials are correct
- Verify massive.com is accessible
- Login page structure may have changed (RSC payload parsing)

### Missing Asset Classes

If you expect an asset class but it doesn't appear in `asset_classes`:
- Asset must appear in either `max_websocket_connections_by_asset_type` OR `rate_limit_by_asset_type`
- Check your subscription includes that asset class
- Verify with `./dev/fetch_polygon_accounts.rb` to see raw API response

### Rate Limit Assumptions

The gem assumes:
- Values in `rate_limit_by_asset_type` are per minute (window: 60)
- Missing assets are unlimited (99 requests per second, window: 1)

These assumptions are based on typical Polygon.io behavior but may need adjustment based on your actual rate limits.

## Migration from Previous Versions

If upgrading from an older version that scraped dashboard data:

### Removed Methods:
```ruby
# These no longer exist
client.tier(:stocks)                    # REMOVED
client.tiers                            # REMOVED
client.historical_years(:stocks)        # REMOVED
client.historical_cutoff_date(:stocks)  # REMOVED
client.historical_cutoff_time(:stocks)  # REMOVED
client.realtime?(:stocks)               # REMOVED
```

### Renamed Methods:
```ruby
# OLD                                  # NEW
client.rate_limit(:stocks)          => client.rest_rate_limit(:stocks)
client.rate_limits                  => client.rest_rate_limits
client.max_websocket_connections(:stocks) => client.websocket_connection_limit(:stocks)
```

### New Methods:
```ruby
client.asset_classes                       # NEW
client.websocket_connection_limit(:stocks) # NEW (renamed from max_websocket_connections)
```

### Changed Output Structure:
```ruby
# OLD
info[:resources][:stocks][:tier]           # => "starter"
info[:resources][:stocks][:historical_years] # => 5
info[:paid]                                 # => true

# NEW
info[:assets][:stocks][:websocket_connection_limit] # => 1
info[:assets][:stocks][:rest_rate_limit]            # => { requests: 99, window: 1 }
# (paid, tier, historical_years, websocket_enabled no longer available)
```

## References

- **API Reference**: `context/api-reference.md` - Complete method documentation
- **Architecture**: `context/architecture.md` - How the API integration works
- **Conventions**: `context/conventions.md` - Coding standards (YARD, RBS, testing)
