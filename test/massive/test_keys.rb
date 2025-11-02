require "test_helper"

class TestKeys < Minitest::Test
  def test_parse_keys_from_rows_json
    html_with_keys = <<~HTML
      <script>
      self.__next_f.push([1,"{\\"rows\\":[{\\"name\\":\\"test-key\\",\\"key\\":\\"abc123xyz\\",\\"id\\":\\"key-123\\"}]}"])
      </script>
    HTML

    keys = Massive::Account::Keys.send(:parse_keys, html_with_keys)

    assert_equal 1, keys.length
    assert_equal "test-key", keys[0][:name]
    assert_equal "abc123xyz", keys[0][:key]
    assert_equal "key-123", keys[0][:id]
  end

  def test_parse_keys_empty_html
    html = "<html></html>"

    keys = Massive::Account::Keys.send(:parse_keys, html)

    assert_equal [], keys
  end

  def test_parse_key_details_extracts_api_and_s3_credentials
    html_with_details = <<~HTML
      <script>
      self.__next_f.push([1,"{\\"name\\":\\"my-key\\",\\"keyId\\":\\"id-123\\",\\"accessKey\\":\\"apikey123\\"}"])
      self.__next_f.push([2,"\\"Access Key ID\\":\\"s3-access-123\\""])
      self.__next_f.push([3,"\\"Secret Access Key\\":\\"s3-secret-456\\""])
      self.__next_f.push([4,"\\"S3 Endpoint\\":\\"https://files.massive.com\\""])
      self.__next_f.push([5,"\\"Bucket\\":\\"flatfiles\\""])
      </script>
    HTML

    details = Massive::Account::Keys.send(:parse_key_details, html_with_details)

    assert_equal "my-key", details[:name]
    assert_equal "id-123", details[:id]
    assert_equal "apikey123", details[:api_key]
  end

  def test_fetch_requires_account_id
    assert_raises(ArgumentError) do
      Massive::Account::Keys.fetch(nil, token: "test-token")
    end
  end

  def test_fetch_requires_token
    assert_raises(ArgumentError) do
      Massive::Account::Keys.fetch("account-id", token: nil)
    end
  end

  def test_fetch_key_details_requires_all_params
    assert_raises(ArgumentError) do
      Massive::Account::Keys.fetch_key_details(nil, "key-id", token: "token")
    end

    assert_raises(ArgumentError) do
      Massive::Account::Keys.fetch_key_details("account-id", nil, token: "token")
    end

    assert_raises(ArgumentError) do
      Massive::Account::Keys.fetch_key_details("account-id", "key-id", token: nil)
    end
  end
end
