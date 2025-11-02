# Massive::Account

A Ruby gem to access your [Massive](https://massive.com/) permissions and credentials.

See [`context/getting-started.md`](context/getting-started.md) for complete documentation.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'massive-account'
```

## Setup

Set environment variables:

```bash
export MASSIVE_ACCOUNT_EMAIL="user@example.com"
export MASSIVE_ACCOUNT_PASSWORD="account_passwd"
```

## Usage

```ruby
pp Massive::Account.info
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wtn/massive-account.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
