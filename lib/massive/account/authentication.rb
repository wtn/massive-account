require 'json'
require 'cgi'
require 'base64'

module Massive
  module Account
    # Handles authentication with massive.com
    # @private
    module Authentication
      module_function

      # Authenticates with email and password
      #
      # @param email [String] User's email
      # @param password [String] User's password
      # @return [Hash, nil] Hash with :account_id and :token, or nil if failed
      def authenticate(email, password)
        action_id = fetch_login_action_id
        return nil unless action_id

        response = perform_login(email, password, action_id)
        return nil unless response

        extract_credentials_from_cookies(response)
      end

      # Fetches the Server Action ID from the login page JavaScript
      #
      # @return [String, nil] The action ID or nil if not found
      def fetch_login_action_id
        client = HTTPClient.new

        # Fetch login page to find the JS chunk URL
        response = client.get("/dashboard/login")
        return nil unless response&.code.to_i == 200

        html = response.body

        # Extract login page JS chunk path
        # Pattern: static/chunks/app/(authentication)/(unprotected)/login/page-HASH.js
        chunk_match = html.match(%r{static/chunks/app/\(authentication\)/\(unprotected\)/login/page-[^"]+\.js})
        return nil unless chunk_match

        chunk_path = "/dashboard/_next/#{chunk_match[0]}"

        # Fetch the JS chunk
        js_response = client.get(chunk_path)
        return nil unless js_response&.code.to_i == 200

        js = js_response.body

        # Extract action ID from: createServerReference)("ACTION_ID",...) or createServerReference("ACTION_ID",...)
        # The minified code has format: (0,i.createServerReference)("ACTION_ID",...)
        action_match = js.match(/createServerReference\)?\("([0-9a-f]{40,})"/)
        return nil unless action_match

        action_match[1]
      rescue StandardError
        nil
      end

      def perform_login(email, password, action_id)
        # Next.js Server Actions format (as of Next.js 14+):
        # - Field "1_email": email address
        # - Field "1_password": password
        # - Field "0": previous state from useActionState
        state = [{"isError" => false, "message" => "", "errors" => nil}, "$K1"].to_json

        fields = [
          ["1_email", email],
          ["1_password", password],
          ["0", state],
        ]

        headers = {
          "Accept" => "text/x-component",
          "Origin" => "https://massive.com",
          "Referer" => "https://massive.com/dashboard/login",
          "Next-Action" => action_id,
        }

        client = HTTPClient.new
        client.post("/dashboard/login", fields: fields, headers: headers)
      end

      def extract_credentials_from_cookies(response)
        return nil unless response.code.to_i.between?(200, 399)

        # Extract all cookies
        cookies = response.get_fields('set-cookie')
        return nil unless cookies

        result = {}

        # Extract account ID from massive-account cookie
        account_cookie = cookies.find { |h| h.match?(/massive-account=/) }
        if account_cookie
          cookie_value = account_cookie[/massive-account=([^;]+)/, 1]
          if cookie_value
            decoded = CGI.unescape(CGI.unescape(cookie_value))
            json_str = Base64.decode64(decoded)
            account_data = JSON.parse(json_str)
            result[:account_id] = account_data['id']
          end
        end

        # Extract token from massive-token cookie
        token_cookie = cookies.find { |h| h.match?(/massive-token=/) }
        if token_cookie
          token_value = token_cookie[/massive-token=([^;]+)/, 1]
          result[:token] = token_value if token_value
        end

        result.empty? ? nil : result
      rescue JSON::ParserError, StandardError
        nil
      end
    end
  end
end
