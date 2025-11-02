# Development Scripts

Utility scripts for development and investigation.

## Account Inspection

### `inspect_account.rb`

Displays comprehensive account information including all resources, features, and credentials.

**Usage:**
```bash
ruby dev/inspect_account.rb
```

**Requirements:** `MASSIVE_ACCOUNT_EMAIL` and `MASSIVE_ACCOUNT_PASSWORD` environment variables

**Output:** Formatted display of subscriptions, features, and credentials plus full JSON dump

## Historical Data Investigation

### `CUTOFF_FINDINGS.md`

Documentation of historical data cutoff testing results and findings.

**Key findings:**
- Server-side rule: exactly 1825 days (5 years using 365-day arithmetic)
- "2 Years Historical Data" actually provides ~5 years
- Cutoff date: November 3, 2020 (1825 days from Nov 2, 2025)

### `test_historical_cutoff.rb`

Tests historical data availability at various time points.

**Usage:**
```bash
ruby dev/test_historical_cutoff.rb
```

Tests intraday minute data for AAPL at different dates to verify cutoff boundary.

### `find_exact_cutoff.rb`

Binary search script to find exact historical data cutoff date.

**Usage:**
```bash
ruby dev/find_exact_cutoff.rb
```

### `find_true_cutoff.rb`

Tests yearly intervals to identify the approximate cutoff range.

### `test_endpoint_cutoffs.rb`

Tests different API endpoints (minute aggregates, daily aggregates, trades, quotes) to determine if they have different historical lookback periods.

**Usage:**
```bash
ruby dev/test_endpoint_cutoffs.rb
```

**Finding:** All endpoints share the same 1825-day cutoff for available data types.

## Directories

### `active/`

Placeholder for active development scripts (empty with .gitkeep).

### `completed/`

Placeholder for completed investigation scripts (empty with .gitkeep).

## Environment Variables Required

All scripts require:
- `MASSIVE_ACCOUNT_EMAIL` - Your massive.com email
- `MASSIVE_ACCOUNT_PASSWORD` - Your massive.com password
- `MASSIVE_API_KEY` - Your API key (for API testing scripts)

## Notes

- Scripts use Net::HTTP for simplicity (no external dependencies)
- Rate limiting delays (0.3s) included to respect API limits
- All scripts are executable (chmod +x)
