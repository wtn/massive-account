# Architecture

## Why This Exists

Massive.com doesn't provide a public API for account management. To programmatically access subscription details and credentials, this gem scrapes the web dashboard.

## Core Architecture Decision: RSC Payload Scraping

**Problem**: Need structured data from Massive's Next.js dashboard

**Solution**: Parse React Server Components (RSC) payloads instead of HTML

**Why RSC, not HTML?**
- RSC payloads contain structured JSON data
- More stable than HTML DOM structure
- Easier to extract nested data (features, credentials)
- Pattern: Extract from `<script>self.__next_f.push([...])</script>` tags

**Location**: `lib/massive/account/http_client.rb:extract_rsc_payload`

## Module Separation Strategy

**Why modules instead of classes?**
- Authentication, Resources, Keys are stateless operations
- Client class coordinates them but doesn't implement logic
- Easier to test modules independently with mocks
- Clear separation: Client = public API, Modules = implementation

**Pattern**:
```
Client (public API) → Module.method (implementation) → HTTPClient (HTTP layer)
```

## Key Design Decisions

### Why Memoize `account_info`?

**Problem**: Helper methods (`tier`, `rate_limit`, etc.) would make redundant HTTP requests

**Decision**: Cache `account_info` result in `@account_info` instance variable

**Trade-off**: Data becomes stale if account changes during client lifetime. Acceptable because:
- Subscriptions rarely change mid-session
- Can create new client instance if refresh needed
- Performance benefit outweighs staleness risk

### Why Use Simple Arithmetic for Cutoffs?

**Context**: Server uses `years * 365` days, not calendar-aware `Date#<<` arithmetic

**Decision**: Match server's simple arithmetic in `historical_cutoff_date`

**Testing**: Confirmed with Stocks Starter (5 years):
- Nov 3, 2020 (1825 days ago): Has data ✓
- Nov 2, 2020 (1826 days ago): NOT_AUTHORIZED ✗
- Server cutoff: Exactly `Date.today - 1825`

**Rationale**:
- Returns what the server enforces
- Cutoff is based on advertised period (5 years for Starter, 2 years for Basic)
- Simple arithmetic matches server behavior

### Why Window-Based Rate Limits?

**Context**: Could have used Rational (requests/second) or simple integer

**Decision**: Return `{ requests: N, window: seconds }` structure

**Rationale**:
- Preserves whether limit is per-second (window: 1) or per-minute (window: 60)
- Passed directly to rate limiter implementations (handled in `massive-rest` gem)
- More explicit than normalized req/sec values

## Integration Patterns

### Initializing Massive Clients with Account Info

Typical usage when setting up REST/WebSocket/S3 clients:

```ruby
account = Massive::Account.sign_in(email: email, password: password)

# Get credentials and limits
creds = account.primary_credential_set
limits = account.rate_limits

# Initialize clients for each subscribed resource
account.tiers.each do |resource, tier|
  limit = limits[resource]

  # Setup REST client with rate limiting
  rest_client = Massive::REST.for(resource,
    api_key: creds[:api_key],
    rate_limit: limit
  )

  # Setup WebSocket if available
  if account.websocket?(resource)
    ws_client = Massive::WebSocket.for(resource,
      api_key: creds[:api_key]
    )
  end
end

# S3 for flat files (if available)
if account.account_info[:resources]["stocks"][:features]["flat_files"]
  s3 = Aws::S3::Client.new(
    access_key_id: creds[:s3][:access_key_id],
    secret_access_key: creds[:s3][:secret_access_key],
    endpoint: creds[:s3][:endpoint]
  )
end
```

## References

- massive.com dashboard: https://massive.com/dashboard
- RBS type signatures: `sig/massive/account.rbs`
- Tests: `test/massive/`
