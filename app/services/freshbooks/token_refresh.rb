# frozen_string_literal: true

module Freshbooks
  module TokenRefresh
    # Refresh access token 1 hour before expiry to avoid edge cases
    REFRESH_BUFFER_SECONDS = 3600

    def refresh_token_if_needed
      return unless @refresh_token.present?

      token = FreshbooksToken.current
      return unless token&.expires_soon?(buffer_seconds: REFRESH_BUFFER_SECONDS) || token&.expired?

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
      if config[:client_id].blank? || config[:client_secret].blank?
        raise FreshbooksError.new(
          'FreshBooks OAuth credentials not configured (CLIENT_ID and CLIENT_SECRET required for token refresh)',
          nil,
          nil
        )
      end
      return unless config[:redirect_uri].blank?

      raise FreshbooksError.new(
        'FRESHBOOKS_REDIRECT_URI required for token refresh (must match the redirect URI used during authorization)',
        nil,
        nil
      )
    end

    def request_token_refresh
      config = Rails.application.config.freshbooks
      # Per FreshBooks docs: token endpoint is api.freshbooks.com (not auth.freshbooks.com)
      # https://www.freshbooks.com/api/authentication
      token_url = "#{config[:api_base_url]}/auth/oauth/token"
      body = {
        grant_type: 'refresh_token',
        refresh_token: @refresh_token,
        client_id: config[:client_id],
        client_secret: config[:client_secret],
        redirect_uri: config[:redirect_uri]
      }
      HTTParty.post(
        token_url,
        body: body.to_json,
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

      # When refresh token is invalid/expired/revoked, user must re-authenticate via OAuth.
      # Raise a specific error with the re-auth URL for one-click recovery.
      if refresh_token_invalid?(response)
        reauth_url = build_reauth_url
        Rails.logger.error "Re-authentication required. Visit: #{reauth_url}"
        raise FreshbooksTokenExpiredError.new(
          error_message,
          response.code,
          response.body,
          reauth_url: reauth_url
        )
      end

      raise FreshbooksError.new(error_message, response.code, response.body)
    end

    def refresh_token_invalid?(response)
      return false unless response.code == 400
      return false unless response.body.present?

      body = response.body.downcase
      body.include?('invalid') || body.include?('expired') || body.include?('revoked')
    end

    def build_reauth_url
      Freshbooks::OauthService.auth_url
    rescue StandardError
      nil
    end
  end
end
