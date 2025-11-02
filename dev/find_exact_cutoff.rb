#!/usr/bin/env ruby
# frozen_string_literal: true

# Find the exact historical cutoff date
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

def has_data?(date, api_key)
  from_timestamp = Time.new(date.year, date.month, date.day, 9, 30, 0, "-05:00").to_i * 1000
  to_timestamp = Time.new(date.year, date.month, date.day, 16, 0, 0, "-05:00").to_i * 1000

  uri = URI("https://api.massive.com/v2/aggs/ticker/AAPL/range/1/minute/#{from_timestamp}/#{to_timestamp}")
  uri.query = URI.encode_www_form(apiKey: api_key, limit: 1)

  response = Net::HTTP.get_response(uri)
  data = JSON.parse(response.body)

  data['results'] && !data['results'].empty?
rescue
  false
end

puts "Finding exact historical data cutoff..."
puts "Today: #{Date.today}"
puts

# Binary search to find cutoff
recent_date = Date.today - 365  # Known to have data
old_date = Date.today - 1825    # 5 years ago, likely no data

puts "Testing boundaries:"
puts "  Recent (#{recent_date}): #{has_data?(recent_date, api_key) ? 'HAS DATA' : 'NO DATA'}"
sleep 0.3
puts "  Old (#{old_date}): #{has_data?(old_date, api_key) ? 'HAS DATA' : 'NO DATA'}"
sleep 0.3

puts "\nBinary searching for cutoff..."

while (old_date - recent_date).abs > 7
  mid_date = recent_date - ((recent_date - old_date) / 2)

  # Skip weekends
  mid_date -= 1 while mid_date.saturday? || mid_date.sunday?

  has_mid = has_data?(mid_date, api_key)
  puts "  Testing #{mid_date} (#{(Date.today - mid_date).to_i} days ago): #{has_mid ? 'HAS DATA' : 'NO DATA'}"

  if has_mid
    recent_date = mid_date
  else
    old_date = mid_date
  end

  sleep 0.3
end

puts "\nNarrowing down to exact date..."

# Now search day by day around the boundary
test_range = (old_date..recent_date).to_a.reject { |d| d.saturday? || d.sunday? }

test_range.each do |date|
  has_it = has_data?(date, api_key)
  marker = has_it ? '✓' : '✗'
  puts "#{marker} #{date} (#{(Date.today - date).to_i} days ago)"
  sleep 0.3
end

puts "\n" + "=" * 80
puts "CUTOFF ANALYSIS"
puts "=" * 80

# Find the exact cutoff
cutoff_date = test_range.find { |d| !has_data?(d, api_key) }
if cutoff_date
  days_back = (Date.today - cutoff_date).to_i
  puts "Exact cutoff: #{cutoff_date} (#{days_back} days ago)"
  puts "Last available: #{cutoff_date + 1} (#{days_back - 1} days ago)"
  puts "Formula: Date.today - #{days_back - 1} days"
else
  puts "All dates in range have data!"
end
