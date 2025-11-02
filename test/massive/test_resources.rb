require "test_helper"

class TestResources < Minitest::Test
  def test_parse_resources_with_valid_data
    # Mock HTML with RSC payload containing subscription data
    html = <<~HTML
      <script>
      self.__next_f.push([1,"{\\"product_line\\":\\"stocks\\",\\"plan_name\\":\\"Stocks Starter\\",\\"api_calls\\":\\"Unlimited API Calls\\"}"])
      self.__next_f.push([2,"{\\"product_line\\":\\"options\\",\\"plan_name\\":\\"Options Basic\\"}"])
      </script>
    HTML

    resources = Massive::Account::Resources.send(:parse_resources, html)

    assert_instance_of Hash, resources
  end

  def test_parse_resources_with_no_data
    html = "<html><body>No subscription data</body></html>"

    resources = Massive::Account::Resources.send(:parse_resources, html)

    assert_equal({}, resources)
  end

  def test_fetch_requires_account_id
    assert_raises(ArgumentError) do
      Massive::Account::Resources.fetch(nil, token: "test-token")
    end

    assert_raises(ArgumentError) do
      Massive::Account::Resources.fetch("", token: "test-token")
    end
  end
end
