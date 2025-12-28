# frozen_string_literal: true

module Freshbooks
  # Helper methods for PDF validation and logging
  module InvoicePdfValidationHelpers
    def safe_body_start(body)
      body[0..10]
    rescue StandardError
      ''
    end

    def valid_pdf_content?(response)
      response.body.start_with?('%PDF') || pdf_content_type?(response)
    end

    def pdf_content_type?(response)
      response.headers['content-type']&.include?('application/pdf')
    end

    def log_invalid_pdf_warning(response, body_start)
      if response.success?
        Rails.logger.warn("Response doesn't appear to be PDF. Starts with: #{body_start.inspect}")
      else
        Rails.logger.warn("PDF request failed: code=#{response.code}, body=#{response.body[0..200]}")
      end
    end

    def log_pdf_binary_error(error)
      Rails.logger.error("Failed to get PDF binary: #{error.message}")
      Rails.logger.error("Backtrace: #{error.backtrace.first(5).join('\n')}")
    end
  end
end
