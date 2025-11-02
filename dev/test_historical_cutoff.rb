#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple HTTP test to determine historical data cutoff using intraday minute data
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

def test_intraday_minute(date, api_key)
  # Test for minute bars on a specific date (market hours: 9:30-16:00 ET)
  from_timestamp = Time.new(date.year, date.month, date.day, 9, 30, 0, "-05:00").to_i * 1000
  to_timestamp = Time.new(date.year, date.month, date.day, 16, 0, 0, "-05:00").to_i * 1000

  uri = URI("https://api.massive.com/v2/aggs/ticker/AAPL/range/1/minute/#{from_timestamp}/#{to_timestamp}")
  uri.query = URI.encode_www_form(apiKey: api_key, limit: 1)

  response = Net::HTTP.get_response(uri)
  data = JSON.parse(response.body)

  # Debug: show full response for first few
  # puts "  Response: #{data.inspect}"

  if data['results'] && !data['results'].empty?
    bar_timestamp = data['results'].first['t']
    bar_time = Time.at(bar_timestamp / 1000).utc
    { success: true, time: bar_time, count: data['resultsCount'], status: data['status'] }
  else
    # Status OK with no results likely means no trading day (weekend/holiday)
    { success: false, error: data['error'] || 'No results', status: data['status'], weekend: date.saturday? || date.sunday? }
  end
rescue => e
  { success: false, error: e.message }
end

puts "Testing historical intraday (minute) data cutoff for 2-year lookback..."
puts "Today: #{Date.today}"
puts "Current time: #{Time.now}"
puts

# Test various dates going back in time
test_dates = [
  Date.today - 1,       # Yesterday
  Date.today - 7,       # 1 week ago
  Date.today - 365,     # 1 year ago
  Date.today - 730,     # 2 years ago (365 * 2)
  Date.today - 731,     # 2 years + 1 day ago
  Date.today - 732,     # 2 years + 2 days ago
  Date.today - 1095,    # 3 years ago
]

test_dates.each do |date|
  days_ago = (Date.today - date).to_i
  result = test_intraday_minute(date, api_key)

  if result[:success]
    puts "✓ #{date} (#{days_ago} days ago) - SUCCESS - Got minute data at #{result[:time]}"
  elsif result[:weekend]
    puts "○ #{date} (#{days_ago} days ago) - WEEKEND (no trading)"
  else
    puts "✗ #{date} (#{days_ago} days ago) - FAILED: #{result[:error]} (status: #{result[:status]})"
  end

  sleep 0.3  # Rate limiting
end

puts
puts "=" * 80
puts "Testing exact 2-year boundary (minute granularity)..."
puts "=" * 80

# Test around exactly 2 years (730 days)
two_years_ago = Date.today - 730

(-5..5).each do |offset|
  date = two_years_ago + offset
  days_ago = (Date.today - date).to_i

  result = test_intraday_minute(date, api_key)

  if result[:success]
    puts "✓ #{date} (#{days_ago} days) - HAS MINUTE DATA"
  elsif result[:weekend]
    puts "○ #{date} (#{days_ago} days) - WEEKEND"
  else
    puts "✗ #{date} (#{days_ago} days) - NO DATA: #{result[:error]} (status: #{result[:status]})"
  end

  sleep 0.3
end

puts
puts "=" * 80
puts "SUMMARY"
puts "=" * 80
puts "This test queries for 1-minute intraday bars for AAPL"
puts "A successful response means minute-level historical data is available"
puts "The cutoff should show exactly where the 2-year lookback ends"
