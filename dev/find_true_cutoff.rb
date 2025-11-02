#!/usr/bin/env ruby
# frozen_string_literal: true

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

puts "Testing yearly intervals to find true cutoff..."
puts "Today: #{Date.today}"
puts

# Test going back year by year
years_to_test = (1..10).map { |y| Date.today - (y * 365) }

years_to_test.each do |date|
  # Find a weekday
  date -= 1 while date.saturday? || date.sunday?

  has_it = has_data?(date, api_key)
  marker = has_it ? '✓' : '✗'
  years_ago = ((Date.today - date) / 365.0).round(1)
  puts "#{marker} #{date} (~#{years_ago} years ago, #{(Date.today - date).to_i} days): #{has_it ? 'HAS DATA' : 'NO DATA'}"
  sleep 0.3
end
