require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module BulletServices
  class Application < Rails::Application
    # Configure allowed hosts from environment variables
    # For development/testing: ALLOWED_HOSTS=localhost,127.0.0.1,ngrok-url
    # For production: ALLOWED_HOSTS=bullet-services.onrender.com,yourdomain.com
    allowed_hosts = ENV.fetch('ALLOWED_HOSTS', '').split(',').map(&:strip).reject(&:blank?)
    allowed_hosts.each { |host| config.hosts << host } if allowed_hosts.any?

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # rails_admin is ignored because it contains explicitly required files
    config.autoload_lib(ignore: %w[assets tasks rails_admin])
    config.action_mailer.deliver_later_queue_name = "mailers"

    # Set global default URL options for all environments
    config.after_initialize do
      Rails.application.routes.default_url_options = {
        host: ENV.fetch("DEFAULT_URL_HOST", "localhost"),
        port: ENV.fetch("DEFAULT_URL_PORT", 3000)
      }

      # Set ActiveStorage::Current.url_options globally
      ActiveStorage::Current.url_options = {
        host: ENV.fetch("DEFAULT_URL_HOST", "localhost"),
        port: ENV.fetch("DEFAULT_URL_PORT", 3000)
      }
    end

    # Configure Active Storage to use proxy routes (avoids CORS issues)
    config.active_storage.resolve_model_to_route = :rails_storage_proxy

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = false
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore
  end
end
