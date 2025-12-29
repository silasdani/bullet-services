# frozen_string_literal: true

Sentry.init do |config|
  # Better Stack DSN (Sentry-compatible)
  config.dsn = ENV.fetch(
    'SENTRY_DSN',
    'https://HVdWjmQPhCwiAf85g1evoFJX@s1654817.eu-nbg-2.betterstackdata.com/1654817'
  )

  # Set environment (development, staging, production)
  config.environment = ENV.fetch('RAILS_ENV', 'development')

  # Set traces_sample_rate to 1.0 to capture 100% of transactions for performance monitoring
  # Adjust this value in production based on your needs
  config.traces_sample_rate = ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', '0.1').to_f

  # Set profiles_sample_rate to profile 100% of sampled transactions
  # Adjust this value in production based on your needs
  config.profiles_sample_rate = ENV.fetch('SENTRY_PROFILES_SAMPLE_RATE', '0.1').to_f

  # Filter out sensitive parameters
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Don't send events in development/test unless explicitly enabled
  config.enabled_environments = %w[production staging development]
  config.enabled_environments << ENV['RAILS_ENV'] if ENV['SENTRY_ENABLED'] == 'true'

  # Capture unhandled exceptions from background jobs
  config.before_send = lambda do |event, hint|
    # Filter out sensitive data if needed
    event
  end
end
