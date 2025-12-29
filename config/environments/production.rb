require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :amazon

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Configure SSL options for reverse proxy setup
  config.ssl_options = {
    redirect: { exclude: ->(request) { request.path == "/up" } },
    hsts: { subdomains: true, preload: true }
  }

  # Trust the reverse proxy headers
  config.action_dispatch.trusted_proxies = ActionDispatch::RemoteIp::TRUSTED_PROXIES + [ "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16" ]

  # Configure for reverse proxy
  config.action_dispatch.x_forwarded_host = true
  config.action_dispatch.x_forwarded_scheme = true
  config.action_dispatch.x_forwarded_ssl = true

  # Ensure proper handling of forwarded headers
  config.action_dispatch.x_forwarded_for = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use Redis for cache store in production (persistent across restarts)
  # Fall back to memory_store if Redis is not available (for development/testing)
  if ENV['REDIS_URL'].present?
    config.cache_store = :redis_cache_store, {
      url: ENV['REDIS_URL'],
      namespace: 'bullet-services-cache',
      expires_in: 90.minutes
    }
  else
    # Memory store is not persistent - only use if Redis unavailable
    Rails.logger.warn 'WARNING: Using memory cache store. Set REDIS_URL for persistent caching.'
    config.cache_store = :memory_store
  end

  # Active Job adapter (default to inline for low traffic; can toggle via ENV)
  active_job_adapter = ENV.fetch("ACTIVE_JOB_ADAPTER", "inline").to_sym
  config.active_job.queue_adapter = active_job_adapter
  if active_job_adapter == :solid_queue
    config.solid_queue.connects_to = { database: { writing: :queue } }
  end

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = {
    host: ENV.fetch("DEFAULT_URL_HOST", "example.com"),
    port: ENV.fetch("DEFAULT_URL_PORT", 443)
  }

  # Use MailerSend via custom delivery method
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = MailerSendDeliveryMethod

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
