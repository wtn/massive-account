# Getting Started

## What This Gem Does

Fetches your massive.com account details (subscriptions, API keys, S3 credentials) for use in other Massive clients (REST, WebSocket, S3).

Uses a hybrid approach combining:
- **Polygon API** (`api.polygon.io`) for structured account metadata
- **Dashboard scraping** for detailed product features and tier information

## Quickstart

**Set environment variables:**
```bash
export MASSIVE_ACCOUNT_EMAIL="your@email.com"
export MASSIVE_ACCOUNT_PASSWORD="your_password"
```

**Most common usage (no client needed):**
```ruby
require 'massive/account'

# Get everything with one call (uses ENV variables)
info = Massive::Account.info

# Account metadata (from Polygon API)
info[:account_id]        # => "6d26daa4-675d-452d-b693-8dfbb5086095"
info[:email]             # => "your@email.com"
info[:subscription_id]   # => "sub_..."
info[:provider]          # => "polygon"
info[:billing_interval]  # => "month"
info[:paid]              # => true

# Access normalized resource data (from dashboard scraping)
info.dig(:resources, :stocks, :tier)           # => "starter"
info.dig(:resources, :stocks, :historical_years)  # => 5
info.dig(:resources, :stocks, :rate_limit)     # => { requests: 99, window: 1 }
info.dig(:resources, :stocks, :delay_minutes)  # => 15
info.dig(:resources, :stocks, :websocket)      # => true

# API rate limits are also included when available
info.dig(:resources, :options, :api_rate_limit)  # => 5 (requests/minute from API)

# Get credentials
creds = info[:credential_sets].find { |c| c[:name] == "Default" }
creds[:api_key]  # For REST/WebSocket
creds[:s3]       # For S3
```

**Advanced usage (if you need a client instance):**
```ruby
client = Massive::Account.sign_in(email: "user@example.com", password: "password")

client.tier(:stocks)              # => "starter"
client.rate_limit(:stocks)        # => { requests: 99, window: 1 }
client.historical_years(:stocks)  # => 5
```

See `context/api-reference.md` for complete method documentation.

## Key Non-Obvious Behaviors

### Historical Data Cutoff Calculation

**Server uses simple day arithmetic**: `years * 365` days, NOT calendar-aware date math.

For "5 Years Historical Data" (Stocks Starter):
- Server cutoff: `Date.today - 1825` (exactly 5 * 365 days)
- Tested boundary: Nov 3, 2020 (1825 days ago) has data ✓, Nov 2, 2020 (1826 days ago) returns NOT_AUTHORIZED ✗

For "2 Years Historical Data" (Options/Forex Basic):
- Server cutoff: `Date.today - 730` (2 * 365 days)

**Why this matters**: Don't use `Date#<<` for cutoff calculations - the server uses simple arithmetic, so we match it.

### Multiple Credential Sets Per Account

What Massive calls "API Keys" on their dashboard are **credential sets**, each containing:
- API key (for REST/WebSocket)
- S3 credentials (same key used as secret)

```ruby
# All keys are symbols for consistency
client.account_info[:credential_sets]
# => [{ name: "Default", api_key: "...", s3: {...} }, ...]

# Resources use symbol keys too
client.account_info.dig(:resources, :stocks, :tier)  # => "starter"
```

Accounts can have multiple named sets (e.g., "Production", "Development", "Default").

### Primary Credential Selection Logic

`primary_credential_set` priority order:
1. Credential named "Default" (case-insensitive)
2. Last credential in list (oldest, assuming it's the original)

```ruby
# With credentials: ["example_3", "example_2", "Default"]
client.primary_credential_set[:name]  # => "Default" (not "example_3")

# Without "Default": ["example_3", "example_2"]
client.primary_credential_set[:name]  # => "example_2" (last/oldest)
```

**Why this matters**: Don't assume array order for primary selection.

## Important Gotchas

### Rate Limit Window-Based Format

Rate limits are returned as `{ requests: N, window: seconds }`:

```ruby
limit = client.rate_limit(:stocks)
# => { requests: 99, window: 1 }     # 99 requests per 1 second
# => { requests: 5, window: 60 }     # 5 requests per 60 seconds
```

### Account Info is Memoized

First call to `account_info` makes HTTP requests and caches the result. All helper methods (`tier`, `rate_limit`, `historical_years`, etc.) use this cached data.

```ruby
# Makes HTTP requests, caches result
info = client.account_info

# Uses cached data (no HTTP)
client.tier(:stocks)
client.rate_limit(:stocks)
```

**Why this matters**: Safe to call helpers multiple times without performance penalty.

### S3 Credentials Use Same Key

The S3 `secret_access_key` is identical to the API key:

```ruby
creds = client.primary_credential_set
creds[:api_key]                    # "mUzEWsXhurbB5PcsJxX5WgUthlJKPDmt"
creds[:s3][:secret_access_key]     # "mUzEWsXhurbB5PcsJxX5WgUthlJKPDmt" (same!)
creds[:s3][:access_key_id]         # "498d599f-cf4c-4551-bf1c-66f8cdeacc63" (different)
```

## Troubleshooting

### Authentication Returns Nil

Massive uses CSRF tokens from the login page form. If authentication fails:
- Check credentials are correct
- Verify massive.com is accessible
- Login page structure may have changed (RSC payload parsing)

### Missing Features in Parsed Data

The gem uses a hybrid approach:
- **API data** (`api.polygon.io/accountservices/v1/accounts`): Structured account metadata, rate limits
- **Scraped data** (dashboard pages): Product details, features, tiers, historical years

If features are missing:
- Check if dashboard UI changed (RSC payload structure)
- Features with value `"$undefined"` or `"unavailable"` are filtered out
- See `lib/massive/account/resources.rb:68` for scraping logic
- See `lib/massive/account/api.rb` for API integration

### Why Hybrid Approach?

The Polygon API provides reliable structured data but lacks:
- Product tier names (basic/starter/developer/advanced)
- Feature availability (flat_files, snapshot, trades, quotes, etc.)
- Historical data periods (years)
- Realtime vs delayed status

Dashboard scraping fills these gaps, giving you complete account information.

## References

- **API Reference**: `context/api-reference.md` - Complete method documentation
- **Architecture**: `context/architecture.md` - How scraping works, design decisions
- **Conventions**: `context/conventions.md` - Coding standards (YARD, RBS, testing)
