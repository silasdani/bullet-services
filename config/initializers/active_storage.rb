# Configure ActiveStorage URL options
Rails.application.config.after_initialize do
  # Set default URL options if not already set
  default_options = { host: "localhost", port: 3000 }

  # Set routes default URL options
  Rails.application.routes.default_url_options = default_options

  # Set ActiveStorage::Current.url_options
  ActiveStorage::Current.url_options = default_options

  # Also set the config value
  Rails.application.config.active_storage.default_url_options = default_options

  puts "ActiveStorage URL options configured: #{ActiveStorage::Current.url_options.inspect}"
end
