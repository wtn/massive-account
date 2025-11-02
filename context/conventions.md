# Conventions

## Non-Standard Practices

### Use `module_function` for Stateless Modules

Authentication, Resources, and Keys modules use `module_function` instead of class methods:

```ruby
module Authentication
  module_function  # Makes methods callable as Authentication.method

  def authenticate(email, password)
    # ...
  end
end
```

**Why**: These are pure functions with no state. Module functions are simpler than singleton classes.

### Private Implementation Methods

Parsing and HTTP helper methods are marked `private` using `private` keyword (not `private_class_method`):

```ruby
module Resources
  def self.fetch(account_id, token:)
    # Public
  end

  private

  def self.parse_resources(html)
    # Private implementation
  end
end
```

## Testing Approach

### Stub External HTTP Calls

Never make real HTTP requests in tests. Always stub at the module level:

```ruby
Massive::Account::Authentication.stub :authenticate, credentials do
  # Test code
end
```

**Why**: Tests should be fast, deterministic, and not require network/credentials.

### Test RSC Parsing with Realistic Payloads

Use actual RSC payload structure in test fixtures:

```ruby
html = <<~HTML
  <script>
  self.__next_f.push([1,"{\\"name\\":\\"my-key\\",\\"keyId\\":\\"id-123\\"}"])
  </script>
HTML
```

**Why**: Ensures parsing logic matches real dashboard structure.

## Documentation Standards

### YARD for Public Methods Only

Use YARD documentation for public API methods. Include `@example` when behavior isn't obvious:

```ruby
# Returns the primary credential set
#
# Priority order:
# 1. Credential named "Default" (if exists)
# 2. Last credential in list (oldest)
#
# @return [Hash, nil] Primary credential set
def primary_credential_set
  # ...
end
```

**When to skip YARD**: Private methods, trivial getters/setters

### RBS Type Signatures

Maintain accurate types in `sig/massive/account.rbs`. Update when:
- Adding new methods
- Changing return types
- Adding optional parameters

**Non-obvious type patterns used:**
```ruby
String | Symbol      # Methods accept both
Hash[Symbol, String] # S3 credentials hash
```

## Error Handling Pattern

**ArgumentError for invalid input**, **nil for not found**:

```ruby
def fetch(account_id, token:)
  raise ArgumentError, "account_id is required" if account_id.nil?
  # ...
  return nil unless response.success?  # Not found = nil
end
```

**Why**: Distinguishes between programmer error (ArgumentError) vs runtime condition (nil).

## References

- See `context/api-reference.md` for complete API documentation
- See `context/architecture.md` for design decisions
