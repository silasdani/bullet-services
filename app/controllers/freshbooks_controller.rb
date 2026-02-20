# frozen_string_literal: true

# One-click FreshBooks reconnection: redirects admin to OAuth URL.
# After authorizing, user is redirected to /freshbooks/callback which exchanges the code for tokens.
class FreshbooksController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin

  def reconnect
    redirect_to Freshbooks::OauthService.auth_url, allow_other_host: true
  rescue FreshbooksError => e
    Rails.logger.error "FreshBooks reconnect failed: #{e.message}"
    redirect_to avo_dashboard_path,
                alert: "FreshBooks OAuth not configured: #{e.message}. Set FRESHBOOKS_CLIENT_ID and FRESHBOOKS_REDIRECT_URI."
  end

  private

  def ensure_admin
    return if current_user&.is_admin?

    redirect_to root_path, alert: 'You are not authorized to access this page.'
  end
end
