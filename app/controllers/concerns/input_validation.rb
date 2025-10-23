# frozen_string_literal: true

# app/controllers/concerns/input_validation.rb
module InputValidation
  extend ActiveSupport::Concern

  private

  def sanitize_params(params_to_sanitize = nil)
    # Don't modify params directly as it might be frozen
    # This method is here for future use but not actively used
    true
  end

  def validate_file_upload(file)
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
