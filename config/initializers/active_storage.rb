# Configure ActiveStorage URL options
Rails.application.config.after_initialize do
  ActiveStorage::Current.url_options = Rails.application.routes.default_url_options
end
