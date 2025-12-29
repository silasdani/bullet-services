# frozen_string_literal: true

module Freshbooks
  module Invoices
    # Module containing PDF-related methods for the Invoices class
    module PdfMethods
      include Freshbooks::Invoices::PdfValidationHelpers
      def get_pdf(invoice_id)
        path = build_path("invoices/invoices/#{invoice_id}/pdf")

        begin
          response = make_request(:get, path)
          pdf_data = response.dig('response', 'result', 'pdf')
          return pdf_data if pdf_data.present?
        rescue StandardError => e
          Rails.logger.warn("JSON PDF request failed: #{e.message}")
        end

        nil
      end

      def get_pdf_as_base64(invoice_id)
        path = build_path("invoices/invoices/#{invoice_id}/pdf")

        base64_from_binary = try_binary_to_base64(invoice_id)
        return base64_from_binary if base64_from_binary.present?

        extract_base64_from_json_response(path)
      end

      def get_pdf_binary(invoice_id)
        path = build_path("invoices/invoices/#{invoice_id}/pdf")
        full_url = "#{self.class.base_uri}#{path}"

        return nil unless token_available?

        response = fetch_pdf_http_response(full_url)
        validate_and_return_pdf(response)
      rescue StandardError => e
        log_pdf_binary_error(e)
        nil
      end

      private

      def try_binary_to_base64(invoice_id)
        pdf_bytes = get_pdf_binary(invoice_id)
        return nil unless pdf_bytes.present? && pdf_bytes.start_with?('%PDF')

        Base64.strict_encode64(pdf_bytes)
      rescue StandardError => e
        Rails.logger.warn("Binary PDF fetch failed: #{e.message}")
        nil
      end

      def extract_base64_from_json_response(path)
        response = make_request(:get, path)
        pdf_data = find_base64_in_response(response)

        pdf_data if pdf_data.is_a?(String) && pdf_data.length > 100
      end

      def find_base64_in_response(response)
        direct_pdf = response.dig('response', 'result', 'pdf')
        return direct_pdf if direct_pdf.is_a?(String) && direct_pdf.length > 100

        try_nested_base64_paths(response)
      end

      def try_nested_base64_paths(response)
        paths = [
          %w[response result pdf content],
          %w[response result pdf data],
          %w[response result content],
          %w[response result pdf base64]
        ]

        paths.each do |path_keys|
          data = response.dig(*path_keys)
          return data if data.is_a?(String) && data.length > 100
        end

        nil
      end

      def token_available?
        token = FreshbooksToken.current
        return true if token

        Rails.logger.error('No FreshBooks token available for PDF download')
        false
      end

      def fetch_pdf_http_response(full_url)
        options = build_pdf_request_options
        Rails.logger.info("Attempting to fetch PDF binary from: #{full_url}")
        response = HTTParty.get(full_url, options)

        log_pdf_response_info(response)
        response
      end

      def build_pdf_request_options
        token = FreshbooksToken.current
        {
          headers: {
            'Authorization' => "Bearer #{token.access_token}",
            'Api-Version' => 'alpha',
            'Accept' => 'application/pdf'
          }
        }
      end

      def log_pdf_response_info(response)
        Rails.logger.info(
          "PDF binary response code: #{response.code}, " \
          "content-type: #{response.headers['content-type']}, " \
          "body length: #{response.body&.length}"
        )
      end

      def validate_and_return_pdf(response)
        return nil unless response.success? && response.body.present?

        body_start = safe_body_start(response.body)
        Rails.logger.info("PDF body starts with: #{body_start.inspect}")

        return response.body if valid_pdf_content?(response)

        log_invalid_pdf_warning(response, body_start)
        nil
      end
    end
  end
end
