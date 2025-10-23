# frozen_string_literal: true

# app/controllers/concerns/input_validation.rb
module InputValidation
  extend ActiveSupport::Concern

  private

  def sanitize_params(params)
    params.each do |key, value|
      if value.is_a?(String)
        params[key] = value.strip
      elsif value.is_a?(Hash)
        sanitize_params(value)
      end
    end
  end

  def validate_file_upload(file)
    return false if file.blank?

    allowed_types = %w[image/jpeg image/png image/gif application/pdf]
    max_size = 10.megabytes

    unless allowed_types.include?(file.content_type)
      add_error("Invalid file type. Allowed: #{allowed_types.join(', ')}")
      return false
    end

    unless file.size <= max_size
      add_error("File too large. Maximum size: #{max_size / 1.megabyte}MB")
      return false
    end

    true
  end
end
