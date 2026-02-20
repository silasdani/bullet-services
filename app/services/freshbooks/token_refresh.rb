# frozen_string_literal: true

module Freshbooks
  module TokenRefresh
    def refresh_token_if_needed
      return unless @refresh_token.present?

      token = FreshbooksToken.current
      # Refresh if token is expired or expires within 5 minutes
      return unless token&.expires_soon? || token&.expired?

      Rails.logger.info 'FreshBooks token expired or expiring soon, refreshing proactively...'
      refresh_access_token
    end

    def refresh_access_token
      validate_oauth_credentials
      response = request_token_refresh

      if response.success?
        update_tokens_from_response(response.parsed_response)
      else
        handle_refresh_error(response)
      end
    end

    def validate_oauth_credentials
      config = Rails.application.config.freshbooks
      return unless config[:client_id].blank? || config[:client_secret].blank?

      raise FreshbooksError.new(
        'FreshBooks OAuth credentials not configured (CLIENT_ID and CLIENT_SECRET required for token refresh)',
        nil,
        nil
      )
    end

    def request_token_refresh
      config = Rails.application.config.freshbooks
      HTTParty.post(
        "#{config[:auth_base_url]}/oauth/token",
        body: {
          grant_type: 'refresh_token',
          refresh_token: @refresh_token,
          client_id: config[:client_id],
          client_secret: config[:client_secret]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    def update_tokens_from_response(data)
      @access_token = data['access_token']
      @refresh_token = data['refresh_token'] || @refresh_token
      update_database_token(data)
    end

    def update_database_token(data)
      token = FreshbooksToken.current
      return unless token

      expires_at = Time.current + data['expires_in'].seconds
      token.update!(
        access_token: @access_token,
        refresh_token: @refresh_token,
        token_expires_at: expires_at
      )
    end

    def handle_refresh_error(response)
      error_message = build_error_message("Failed to refresh access token: #{response.code}", response)
      Rails.logger.error "FreshBooks token refresh failed: #{error_message}"
      Rails.logger.error "Response body: #{response.body}"

      raise FreshbooksError.new(
        error_message,
        response.code,
        response.body
      )
    end
  end
end
