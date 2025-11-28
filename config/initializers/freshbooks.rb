# frozen_string_literal: true

Rails.application.config.freshbooks = {
  # OAuth credentials (for token refresh if needed)
  client_id: ENV.fetch('FRESHBOOKS_CLIENT_ID', nil),
  client_secret: ENV.fetch('FRESHBOOKS_CLIENT_SECRET', nil),
  redirect_uri: ENV.fetch('FRESHBOOKS_REDIRECT_URI', nil),

  # API configuration
  api_base_url: 'https://api.freshbooks.com',
  auth_base_url: 'https://auth.freshbooks.com',

  # Direct token configuration (alternative to database storage)
  # Set these if you're providing tokens via environment variables
  access_token: ENV.fetch('FRESHBOOKS_ACCESS_TOKEN', nil),
  refresh_token: ENV.fetch('FRESHBOOKS_REFRESH_TOKEN', nil),
  business_id: ENV.fetch('FRESHBOOKS_BUSINESS_ID', nil),

  # Webhook verification
  webhook_secret: ENV.fetch('FRESHBOOKS_WEBHOOK_SECRET', nil)
}.freeze
