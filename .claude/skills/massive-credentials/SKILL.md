# Massive Credentials

Get Massive.com account credentials (API keys + S3), subscription tiers, rate limits, and feature availability.

## Environment Variables

Set these for automatic authentication:
- `MASSIVE_ACCOUNT_EMAIL`
- `MASSIVE_ACCOUNT_PASSWORD`

## Quick Start

```ruby
require 'massive/account'

# Most common - uses ENV variables, no client needed
info = Massive::Account.info

# Get credentials
creds = info[:credential_sets].find { |c| c[:name] =~ /default/i }
creds[:api_key]  # For REST/WebSocket
creds[:s3]       # For S3

# Check subscription (normalized data, all symbols)
info.dig(:resources, :stocks, :tier)           # => "starter"
info.dig(:resources, :stocks, :rate_limit)     # => { requests: 99, window: 1 }
info.dig(:resources, :stocks, :historical_years)  # => 5
info.dig(:resources, :stocks, :websocket)      # => true
```

## Key Methods

```ruby
# Tiers
client.tier(:stocks)              # "basic" | "starter" | "developer" | "advanced"
client.tiers                      # All tiers

# Credentials
client.primary_credential_set        # First credential set
client.account_info[:credential_sets] # All credential sets

# Rate Limits (window-based)
client.rate_limit(:stocks)        # { requests: 100, window: 1 }
client.rate_limits                # All rate limits

# Historical Data
client.historical_years(:stocks)       # 5
client.historical_cutoff_date(:stocks) # Date for safe queries

# Data Access
client.realtime?(:stocks)         # true/false
client.websocket?(:stocks)        # true/false

# Summary
client.features(:stocks)          # Combined feature hash
```

## Structure

```ruby
{
  account_id: "uuid",
  resources: {
    "stocks" => { plan: "Plan Name", features: {...} },
    "options" => { plan: "...", features: {...} }
  },
  credentials: [
    {
      id: "uuid",
      name: "Production",
      api_key: "massive_...",
      created_at: "2024-01-01",
      s3: {
        access_key_id: "AKIA...",
        secret_access_key: "...",
        endpoint: "s3.amazonaws.com",
        bucket: "..."
      }
    }
  ]
}
```

## See Also

- `context/getting-started.md` - Full documentation
- `context/architecture.md` - How it works
