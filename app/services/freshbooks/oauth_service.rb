# frozen_string_literal: true

module Freshbooks
  class OauthService
    def self.exchange_code(code)
      new.exchange_code(code)
    end

    def exchange_code(code)
      config = Rails.application.config.freshbooks

      client_id = config[:client_id]
      client_secret = config[:client_secret]
      redirect_uri = config[:redirect_uri]

      if client_id.blank? || client_secret.blank? || redirect_uri.blank?
        raise FreshbooksError, 'FreshBooks OAuth credentials not configured'
      end

      response = HTTParty.post(
        "#{config[:auth_base_url]}/oauth/token",
        body: {
          grant_type: 'authorization_code',
          code: code,
          client_id: client_id,
          client_secret: client_secret,
          redirect_uri: redirect_uri
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      unless response.success?
        error_message = "Failed to exchange authorization code: #{response.code}"
        begin
          parsed = JSON.parse(response.body) if response.body.present?
          error_message += " - #{parsed['error_description'] || parsed['error'] || response.body}"
        rescue JSON::ParserError
          error_message += " - #{response.body}"
        end
        raise FreshbooksError.new(error_message, response.code, response.body)
      end

      data = response.parsed_response
      access_token = data['access_token']
      refresh_token = data['refresh_token']
      expires_in = data['expires_in']

      business_info = fetch_business_info(access_token)
      business_id = business_info['business_id']

      if business_id.blank?
        raise FreshbooksError, 'Could not fetch business_id from FreshBooks API'
      end

      token = FreshbooksToken.find_or_initialize_by(business_id: business_id)
      token.update!(
        access_token: access_token,
        refresh_token: refresh_token,
        token_expires_at: Time.current + expires_in.seconds,
        user_freshbooks_id: business_info['user_id']
      )

      {
        success: true,
        token: token,
        business_id: business_id,
        expires_in: expires_in
      }
    end

    private

    def fetch_business_info(access_token)
      config = Rails.application.config.freshbooks
      response = HTTParty.get(
        "#{config[:api_base_url]}/auth/api/v1/users/me",
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Api-Version' => 'alpha'
        }
      )

      if response.success?
        data = response.parsed_response
        business_data = data.dig('response', 'business') || data.dig('response', 'business_memberships', 0, 'business')

        business_id = business_data&.dig('business_id') ||
                      business_data&.dig('account_id') ||
                      business_data&.dig('id') ||
                      data.dig('response', 'account_id')

        user_id = business_data&.dig('account_id') ||
                  data.dig('response', 'account_id') ||
                  data.dig('response', 'id')

        {
          'business_id' => business_id,
          'user_id' => user_id
        }
      else
        {
          'business_id' => nil,
          'user_id' => nil
        }
      end
    end
  end
end
