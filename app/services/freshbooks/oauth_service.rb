# frozen_string_literal: true

module Freshbooks
  class OauthService
    def self.exchange_code(code)
      new.exchange_code(code)
    end

    def self.auth_url
      new.auth_url
    end

    def auth_url
      config = Rails.application.config.freshbooks
      raise FreshbooksError, 'FRESHBOOKS_CLIENT_ID and FRESHBOOKS_REDIRECT_URI required' if config[:client_id].blank? || config[:redirect_uri].blank?

      base = config[:auth_base_url] || 'https://auth.freshbooks.com'
      params = {
        client_id: config[:client_id],
        response_type: 'code',
        redirect_uri: config[:redirect_uri]
      }
      "#{base}/oauth/authorize?#{params.to_query}"
    end

    def exchange_code(code)
      validate_oauth_config
      response = request_token_exchange(code)
      handle_token_exchange_response(response, code)
    end

    def validate_oauth_config
      config = Rails.application.config.freshbooks
      return unless config[:client_id].blank? || config[:client_secret].blank? || config[:redirect_uri].blank?

      raise FreshbooksError, 'FreshBooks OAuth credentials not configured'
    end

    def request_token_exchange(code)
      config = Rails.application.config.freshbooks
      # Token endpoint is api.freshbooks.com per https://www.freshbooks.com/api/authentication
      token_url = "#{config[:api_base_url]}/auth/oauth/token"
      HTTParty.post(
        token_url,
        body: {
          grant_type: 'authorization_code',
          code: code,
          client_id: config[:client_id],
          client_secret: config[:client_secret],
          redirect_uri: config[:redirect_uri]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    def handle_token_exchange_response(response, _code)
      raise_token_exchange_error(response) unless response.success?

      data = response.parsed_response
      business_info = fetch_business_info(data['access_token'])
      save_token_and_return_result(data, business_info)
    end

    def raise_token_exchange_error(response)
      error_message = build_error_message("Failed to exchange authorization code: #{response.code}", response)
      config = Rails.application.config.freshbooks

      Rails.logger.error "FreshBooks OAuth token exchange failed: #{error_message}"
      Rails.logger.error "Redirect URI: #{config[:redirect_uri]}"

      raise FreshbooksError.new(error_message, response.code, response.body)
    end

    def save_token_and_return_result(data, business_info)
      business_id = business_info['business_id']
      raise FreshbooksError, 'Could not fetch business_id from FreshBooks API' if business_id.blank?

      token = create_or_update_token(data, business_id, business_info)

      {
        success: true,
        token: token,
        business_id: business_id,
        expires_in: data['expires_in']
      }
    end

    def create_or_update_token(data, business_id, business_info)
      token = FreshbooksToken.find_or_initialize_by(business_id: business_id)
      token.update!(
        access_token: data['access_token'],
        refresh_token: data['refresh_token'],
        token_expires_at: Time.current + data['expires_in'].seconds,
        user_freshbooks_id: business_info['user_id']
      )
      token
    end

    def build_error_message(base_message, response)
      return base_message unless response.body.present?

      begin
        parsed = JSON.parse(response.body)
        error_detail = parsed['error_description'] || parsed['error'] || response.body
        "#{base_message} - #{error_detail}"
      rescue JSON::ParserError
        "#{base_message} - #{response.body}"
      end
    end

    private

    def fetch_business_info(access_token)
      response = request_business_info(access_token)

      if response.success?
        extract_business_info_from_response(response.parsed_response)
      else
        { 'business_id' => nil, 'user_id' => nil }
      end
    end

    def request_business_info(access_token)
      config = Rails.application.config.freshbooks
      HTTParty.get(
        "#{config[:api_base_url]}/auth/api/v1/users/me",
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Api-Version' => 'alpha'
        }
      )
    end

    def extract_business_info_from_response(data)
      business_data = extract_business_data(data)
      {
        'business_id' => extract_business_id(business_data, data),
        'user_id' => extract_user_id(business_data, data)
      }
    end

    def extract_business_data(data)
      data.dig('response', 'business') || data.dig('response', 'business_memberships', 0, 'business')
    end

    def extract_business_id(business_data, data)
      business_data&.dig('business_id') ||
        business_data&.dig('account_id') ||
        business_data&.dig('id') ||
        data.dig('response', 'account_id')
    end

    def extract_user_id(business_data, data)
      business_data&.dig('account_id') ||
        data.dig('response', 'account_id') ||
        data.dig('response', 'id')
    end
  end
end
