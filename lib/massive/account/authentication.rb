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
        params = get_form_params
        return nil unless params

        response = perform_login(email, password, params[:action_id], params[:action_key])
        return nil unless response

        extract_credentials_from_cookies(response)
      end

      def get_form_params
        client = HTTPClient.new
        response = client.get('/dashboard/login')

        return nil unless response.code.to_i.between?(200, 399)

        html = response.body

        # Extract action ID from: <input type="hidden" name="$ACTION_1:0" value="{&quot;id&quot;:&quot;...&quot;,...}"/>
        action_id_match = html.match(/name="\$ACTION_1:0"\s+value="([^"]+)"/)
        return nil unless action_id_match

        decoded_value = CGI.unescapeHTML(action_id_match[1])
        action_data = JSON.parse(decoded_value)
        action_id = action_data['id']

        # Extract action key from: <input type="hidden" name="$ACTION_KEY" value="..."/>
        action_key_match = html.match(/name="\$ACTION_KEY"\s+value="([^"]+)"/)
        return nil unless action_key_match

        action_key = action_key_match[1]

        { action_id: action_id, action_key: action_key }
      rescue JSON::ParserError, StandardError
        nil
      end

      def perform_login(email, password, action_id, action_key)
        boundary = "----RubyFormBoundary#{rand(10**16)}"

        body_parts = [
          build_part(boundary, '1_$ACTION_REF_1', ''),
          build_part(boundary, '1_$ACTION_1:0', {"id" => action_id, "bound" => "$@1"}.to_json),
          build_part(boundary, '1_$ACTION_1:1', [{"isError" => false, "message" => "", "errors" => nil}].to_json),
          build_part(boundary, '1_$ACTION_KEY', action_key),
          build_part(boundary, '1_email', email),
          build_part(boundary, '1_password', password),
          build_part(boundary, '0', [{"isError" => false, "message" => "", "errors" => nil}, "$K1"].to_json),
        ]

        body = body_parts.join + "--#{boundary}--\r\n"

        headers = {
          'Content-Type' => "multipart/form-data; boundary=#{boundary}",
          'Accept' => 'text/x-component',
          'Origin' => 'https://massive.com',
          'Next-Action' => action_id,
        }

        client = HTTPClient.new
        client.post('/dashboard/login', body: body, headers: headers)
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

      def build_part(boundary, name, value)
        "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"\r\n\r\n#{value}\r\n"
      end
    end
  end
end
