# Massive::Account

Ruby gem for accessing [Massive](https://massive.com/) account information.

## Configuration

Set environment variables:

```bash
export MASSIVE_ACCOUNT_EMAIL="user@example.com"
export MASSIVE_ACCOUNT_PASSWORD="t9wtXsZuzJVnYApN"
```

### Usage

```ruby
require 'massive/account'

# Get account info
info = Massive::Account.info

# Access account metadata
info[:email]              # => "user@example.com"
info[:asset_classes]      # => [:currencies, :indices, :options, :stocks]

# Check asset configuration
info.dig(:assets, :stocks, :websocket_connection_limit) # => 1
info.dig(:assets, :stocks, :rest_rate_limit)            # => { requests: 99, window: 1 }

# Get API credentials
creds = info[:credential_sets].find { |c| c[:name] == "Default" }
creds[:api_key]           # => "massive_..."
creds[:s3]                # => { access_key_id: "...", secret_access_key: "...", ... }
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wtn/massive-account.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
