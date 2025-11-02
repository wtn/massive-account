require "test_helper"

class TestHTTPClient < Minitest::Test
  def test_extract_rsc_payload
    html = <<~HTML
      <html>
      <script>self.__next_f.push([1,"some data"])</script>
      <script>self.__next_f.push([2,"more data"])</script>
      </html>
    HTML

    result = Massive::Account::HTTPClient.extract_rsc_payload(html)

    assert_includes result, "some data"
    assert_includes result, "more data"
  end

  def test_extract_rsc_payload_with_json
    html = <<~HTML
      <script>self.__next_f.push([1,"{\"key\":\"value\"}"])</script>
    HTML

    result = Massive::Account::HTTPClient.extract_rsc_payload(html)
    assert_includes result, "key"
    assert_includes result, "value"
  end

  def test_extract_rsc_payload_empty_html
    html = "<html><body>No RSC data</body></html>"

    result = Massive::Account::HTTPClient.extract_rsc_payload(html)
    assert_equal "", result
  end
end
