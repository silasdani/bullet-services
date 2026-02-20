# frozen_string_literal: true

# Raised when FreshBooks token refresh fails (refresh token expired/revoked).
# Re-authentication via OAuth is required. Use #reauth_url to redirect the user.
class FreshbooksTokenExpiredError < FreshbooksError
  attr_reader :reauth_url

  def initialize(message, status_code = nil, response_body = nil, reauth_url: nil)
    super(message, status_code, response_body)
    @reauth_url = reauth_url
  end
end
