#!/usr/bin/env ruby
# frozen_string_literal: true

# Test different API endpoints for different historical cutoffs
require 'net/http'
require 'json'
require 'date'
require 'time'
require 'uri'

api_key = ENV['MASSIVE_API_KEY']
unless api_key
  puts "Error: Set MASSIVE_API_KEY environment variable"
  exit 1
end

def test_endpoint(endpoint_name, uri, api_key)
  response = Net::HTTP.get_response(uri)
  data = JSON.parse(response.body)

  has_data = data['results'] && !data['results'].empty?
  {
    has_data: has_data,
    status: data['status'],
    error: data['error'],
    count: data['resultsCount'] || data['results']&.length
  }
rescue => e
  { has_data: false, error: e.message }
end

# Test date: around the 1825-day boundary we found
test_date = Date.new(2020, 11, 3)  # Known to work for minute aggregates
old_date = Date.new(2020, 11, 2)   # Known NOT to work for minute aggregates

puts "Testing different Stock API endpoints..."
puts "Test dates:"
puts "  ✓ #{test_date} (1825 days ago) - should work"
puts "  ✗ #{old_date} (1826 days ago) - should NOT work (minute aggs)"
puts

endpoints = []

# 1. Minute aggregates (intraday)
from_ts = Time.new(test_date.year, test_date.month, test_date.day, 9, 30, 0, "-05:00").to_i * 1000
to_ts = Time.new(test_date.year, test_date.month, test_date.day, 16, 0, 0, "-05:00").to_i * 1000
uri = URI("https://api.massive.com/v2/aggs/ticker/AAPL/range/1/minute/#{from_ts}/#{to_ts}")
uri.query = URI.encode_www_form(apiKey: api_key, limit: 1)
endpoints << ["Minute Aggregates (recent)", uri]

from_ts_old = Time.new(old_date.year, old_date.month, old_date.day, 9, 30, 0, "-05:00").to_i * 1000
to_ts_old = Time.new(old_date.year, old_date.month, old_date.day, 16, 0, 0, "-05:00").to_i * 1000
uri_old = URI("https://api.massive.com/v2/aggs/ticker/AAPL/range/1/minute/#{from_ts_old}/#{to_ts_old}")
uri_old.query = URI.encode_www_form(apiKey: api_key, limit: 1)
endpoints << ["Minute Aggregates (old)", uri_old]

# 2. Daily aggregates
uri = URI("https://api.massive.com/v2/aggs/ticker/AAPL/range/1/day/#{test_date}/#{test_date}")
uri.query = URI.encode_www_form(apiKey: api_key, limit: 1)
endpoints << ["Daily Aggregates (recent)", uri]

uri = URI("https://api.massive.com/v2/aggs/ticker/AAPL/range/1/day/#{old_date}/#{old_date}")
uri.query = URI.encode_www_form(apiKey: api_key, limit: 1)
endpoints << ["Daily Aggregates (old)", uri]

# 3. Daily Open/Close
uri = URI("https://api.massive.com/v1/open-close/AAPL/#{test_date}")
uri.query = URI.encode_www_form(apiKey: api_key)
endpoints << ["Daily Open/Close (recent)", uri]

uri = URI("https://api.massive.com/v1/open-close/AAPL/#{old_date}")
uri.query = URI.encode_www_form(apiKey: api_key)
endpoints << ["Daily Open/Close (old)", uri]

# 4. Trades (tick data)
uri = URI("https://api.massive.com/v3/trades/AAPL")
uri.query = URI.encode_www_form(
  apiKey: api_key,
  timestamp: test_date.to_s,
  limit: 1
)
endpoints << ["Trades (recent)", uri]

uri = URI("https://api.massive.com/v3/trades/AAPL")
uri.query = URI.encode_www_form(
  apiKey: api_key,
  timestamp: old_date.to_s,
  limit: 1
)
endpoints << ["Trades (old)", uri]

# 5. Quotes
uri = URI("https://api.massive.com/v3/quotes/AAPL")
uri.query = URI.encode_www_form(
  apiKey: api_key,
  timestamp: test_date.to_s,
  limit: 1
)
endpoints << ["Quotes (recent)", uri]

uri = URI("https://api.massive.com/v3/quotes/AAPL")
uri.query = URI.encode_www_form(
  apiKey: api_key,
  timestamp: old_date.to_s,
  limit: 1
)
endpoints << ["Quotes (old)", uri]

# Test each endpoint
endpoints.each do |name, uri|
  result = test_endpoint(name, uri, api_key)

  if result[:has_data]
    puts "✓ #{name.ljust(35)} - HAS DATA (#{result[:count]} results)"
  elsif result[:status] == 'NOT_AUTHORIZED'
    puts "✗ #{name.ljust(35)} - NOT_AUTHORIZED (outside subscription)"
  elsif result[:status] == 'OK'
    puts "○ #{name.ljust(35)} - OK but no data (likely valid date, no trading)"
  else
    puts "✗ #{name.ljust(35)} - #{result[:status] || result[:error]}"
  end

  sleep 0.3
end

puts "\n" + "=" * 80
puts "Testing even older dates for daily aggregates..."
puts "=" * 80

# Test daily bars going back further
very_old_dates = [
  Date.new(2019, 1, 2),   # ~7 years ago
  Date.new(2015, 1, 2),   # ~11 years ago
  Date.new(2010, 1, 4),   # ~16 years ago
  Date.new(2005, 1, 3),   # ~21 years ago
]

very_old_dates.each do |date|
  uri = URI("https://api.massive.com/v2/aggs/ticker/AAPL/range/1/day/#{date}/#{date}")
  uri.query = URI.encode_www_form(apiKey: api_key, limit: 1)

  result = test_endpoint("Daily bar", uri, api_key)
  years_ago = ((Date.today - date) / 365.0).round(1)

  if result[:has_data]
    puts "✓ #{date} (~#{years_ago} years ago) - HAS DATA"
  elsif result[:status] == 'NOT_AUTHORIZED'
    puts "✗ #{date} (~#{years_ago} years ago) - NOT_AUTHORIZED"
  else
    puts "○ #{date} (~#{years_ago} years ago) - #{result[:status]}"
  end

  sleep 0.3
end
