# Historical Data Cutoff Findings

## Test Date
November 2, 2025

## Account Tier
Stocks Starter - advertised as "2 Years Historical Data"

## Actual Data Availability

### Summary
Despite being advertised as "2 Years", the actual historical data goes back **approximately 5 years** (1800-1825 days).

### Detailed Findings

| Date | Days Ago | Has Data? |
|------|----------|-----------|
| 2020-11-25 | 1803 | ✓ YES |
| 2020-10-26 | 1833 | ✗ NO |
| 2020-11-03 | 1825 | ✓ YES |
| 2019-11-04 | 2190 | ✗ NO |

### Definitive Server-Side Cutoff

**Testing Date**: November 2, 2025

| Date | Days Ago | Server Response |
|------|----------|-----------------|
| 2020-11-02 | 1826 | NOT_AUTHORIZED ✗ |
| **2020-11-03** | **1825** | **HAS DATA ✓** |

**Server Rule**: Exactly **1825 days** (5 * 365) using simple arithmetic
- Not calendar years (which would be Nov 2, 2020)
- Simple day math: `Date.today - 1825`

## Formula for Cutoff Calculation

The server uses **simple day arithmetic**, NOT calendar-aware date math:

```ruby
# Server's actual rule (confirmed via testing)
server_cutoff_days = years * 365  # e.g., 5 years = 1825 days
server_cutoff_date = Date.today - server_cutoff_days

# For "2 Years Historical Data" (which actually gives 5 years):
advertised_years = 2  # From "2 Years Historical Data"
conservative_cutoff = Date.today - (advertised_years * 365)  # 730 days ago
```

### Recommendation

Since Massive appears to provide **more data than advertised**, we should:

1. **Document the advertised limit** ("2 Years")
2. **Calculate cutoff conservatively** based on advertised years
3. **Not rely on the generous actual limit** since it may change

## Safe Cutoff Formula

```ruby
# Parse "2 Years Historical Data" -> 2
years = historical_data_string.match(/(\d+)\+?\s*Years?/i)[1].to_i

# Calculate cutoff date (conservative, accounts for leap years)
cutoff_date = Date.today << (years * 12)  # Go back N years using month arithmetic

# For time with proper leap year handling
cutoff_date = Date.today << (years * 12)
cutoff_time = Time.new(cutoff_date.year, cutoff_date.month, cutoff_date.day,
                       Time.now.hour, Time.now.min, Time.now.sec, Time.now.utc_offset)
```

### Server Uses Simple Arithmetic (Not Calendar Math)

Testing confirmed the server uses `years * 365` simple arithmetic:
- **5 years = 1825 days** (not calendar years)
- Cutoff: Nov 3, 2020 (1825 days ago)
- Calendar 5 years would be: Nov 2, 2020 (using `Date#<<`)

This means the server is **slightly more generous** than true calendar years (by 1 day after accounting for leap year).

## Notes

- Tested with AAPL minute-level intraday data
- Weekend/holiday gaps expected (no trading days)
- API returns status "OK" with empty results for non-trading days
- Actual data availability is significantly more generous than advertised (5 years vs 2 years)
