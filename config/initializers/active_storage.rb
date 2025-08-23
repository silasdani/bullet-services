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

# Disable ACLs for modern S3 buckets
Rails.application.config.after_initialize do
  if Rails.env.production?
    # Configure Active Storage to not use ACLs
    Rails.application.config.active_storage.service_urls_expire_in = 1.hour

    # Ensure no ACLs are set
    ActiveStorage::Blob.service.class_eval do
      def upload(key, io, **options)
        # Remove any ACL-related options
        options.delete(:acl)
        options.delete(:public_read)
        super(key, io, **options)
      end
    end
  end
end
