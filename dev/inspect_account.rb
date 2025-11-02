#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/massive/account'
require 'json'

# Get credentials from environment
email = ENV['MASSIVE_ACCOUNT_EMAIL']
password = ENV['MASSIVE_ACCOUNT_PASSWORD']

unless email && password
  puts "Error: Set MASSIVE_ACCOUNT_EMAIL and MASSIVE_ACCOUNT_PASSWORD environment variables"
  exit 1
end

# Login
puts "Logging in..."
client = Massive::Account.sign_in(email: email, password: password)

unless client
  puts "Error: Login failed"
  exit 1
end

puts "Login successful!"
puts

# Get account info
info = client.account_info

# Pretty print resources with features
puts "=" * 80
puts "RESOURCES (Subscriptions & Features)"
puts "=" * 80
info[:resources].each do |resource_name, resource_data|
  puts
  puts "#{resource_name.upcase}:"
  puts "  Plan: #{resource_data[:plan]}"
  puts "  Features:"
  resource_data[:features].each do |key, value|
    puts "    #{key}: #{value}"
  end
end

puts
puts "=" * 80
puts "CREDENTIALS"
puts "=" * 80
info[:credentials].each_with_index do |cred, i|
  puts
  puts "Credential Set #{i + 1}:"
  puts "  ID: #{cred[:id]}"
  puts "  Name: #{cred[:name]}"
  puts "  API Key: #{cred[:api_key][0..20]}..." if cred[:api_key]
  puts "  Created: #{cred[:created_at]}"
  if cred[:s3] && !cred[:s3].empty?
    puts "  S3 Access Key: #{cred[:s3][:access_key_id]}"
    puts "  S3 Endpoint: #{cred[:s3][:endpoint]}"
    puts "  S3 Bucket: #{cred[:s3][:bucket]}"
  end
end

puts
puts "=" * 80
puts "FULL JSON OUTPUT"
puts "=" * 80
puts JSON.pretty_generate(info)
