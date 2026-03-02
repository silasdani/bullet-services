# frozen_string_literal: true

module Freshbooks
  # Proactively refreshes the FreshBooks access token when it is expired
  # or within the TokenRefresh::REFRESH_BUFFER_SECONDS window of expiring.
  class ProactiveTokenRefreshService
    def self.call
      new.call
    end

    def call
      token = FreshbooksToken.current
      return unless token&.refresh_token.present?

      client = BaseClient.new(
        access_token: token.access_token,
        refresh_token: token.refresh_token,
        business_id: token.business_id
      )

      client.refresh_token_if_needed
    rescue FreshbooksTokenExpiredError, FreshbooksError => e
      Rails.logger.error "FreshBooks proactive token refresh failed: #{e.class} - #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Unexpected error during FreshBooks proactive token refresh: #{e.class} - #{e.message}"
    end
  end
end
