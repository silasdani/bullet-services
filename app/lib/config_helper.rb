# frozen_string_literal: true

# Helper module for consistent configuration access
# Standardizes access to credentials and environment variables
module ConfigHelper
  module_function

  # Get configuration value with fallback priority:
  # 1. Rails credentials (preferred for secrets)
  # 2. Environment variable
  # 3. Default value (if provided)
  #
  # @param key [String] The configuration key
  # @param env_key [String] Environment variable name (defaults to key.upcase)
  # @param default [Object] Default value if not found
  # @param credentials_path [Array] Path to credentials (e.g., [:freshbooks, :api_key])
  # @return [Object] Configuration value
  def get_config(key:, env_key: nil, default: nil, credentials_path: nil)
    env_key ||= key.to_s.upcase
    credentials_path ||= [key.to_sym]

    # Try credentials first
    value = Rails.application.credentials.dig(*credentials_path)
    return value if value.present?

    # Fall back to environment variable
    value = ENV.fetch(env_key, nil)
    return value if value.present?

    # Return default if provided
    default
  end

  # Get required configuration value (raises if missing)
  def get_config!(key:, env_key: nil, credentials_path: nil)
    value = get_config(key: key, env_key: env_key, credentials_path: credentials_path)
    return value if value.present?

    env_key ||= key.to_s.upcase
    raise "Missing required configuration: #{key} (check credentials or #{env_key} env var)"
  end

  # Get configuration with type conversion
  def get_config_as(key:, type: :string, **)
    value = get_config(key: key, **)
    return nil if value.blank?

    case type
    when :integer
      value.to_i
    when :boolean
      %w[true 1 yes].include?(value.to_s.downcase)
    when :array
      value.is_a?(Array) ? value : value.to_s.split(',').map(&:strip)
    else
      value.to_s
    end
  end
end
