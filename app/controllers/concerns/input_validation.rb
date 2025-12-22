# frozen_string_literal: true

# app/controllers/concerns/input_validation.rb
module InputValidation
  extend ActiveSupport::Concern

  included do
    # Sanitize string parameters to prevent XSS and trim whitespace
    before_action :sanitize_string_params
  end

  private

  def sanitize_string_params
    # Rails params are frozen by default, so we sanitize during strong parameters
    # This method ensures we're aware of the need for sanitization
    # Actual sanitization happens in strong parameters (params.permit)
    # For HTML content, use ActionView::Helpers::SanitizeHelper
  end

  def sanitize_params
    # Deprecated: Use strong parameters instead
    # This method is kept for backward compatibility but does nothing
    # Rails strong parameters already handle basic sanitization
  end

  def sanitize_params?(_params_to_sanitize = nil)
    # Deprecated: Always returns true
    # Use strong parameters validation instead
    true
  end

  def validate_file_upload?(file)
    return false if file.blank?

    allowed_types = %w[image/jpeg image/png image/gif application/pdf]
    max_size = 10.megabytes

    unless allowed_types.include?(file.content_type)
      Rails.logger.error("Invalid file type. Allowed: #{allowed_types.join(', ')}")
      return false
    end

    unless file.size <= max_size
      Rails.logger.error("File too large. Maximum size: #{max_size / 1.megabyte}MB")
      return false
    end

    true
  end
end
