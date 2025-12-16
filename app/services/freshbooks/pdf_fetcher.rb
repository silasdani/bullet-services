# frozen_string_literal: true

module Freshbooks
  # Service for fetching PDF data from FreshBooks invoices
  class PdfFetcher
    def initialize(invoices_client, invoice_id, invoice_data = nil)
      @invoices_client = invoices_client
      @invoice_id = invoice_id
      @invoice_data = invoice_data
    end

    def call
      pdf_data = { base64: nil, download_url: nil }

      pdf_data = try_primary_strategies(pdf_data)
      try_fallback(pdf_data)
    rescue StandardError => e
      Rails.logger.error("Failed to get PDF from FreshBooks API: #{e.message}")
      Rails.logger.error("Error class: #{e.class}")
      Rails.logger.error("Backtrace: #{e.backtrace.first(5).join('\n')}")
      pdf_data
    end

    private

    attr_reader :invoices_client, :invoice_id, :invoice_data

    def try_primary_strategies(pdf_data)
      pdf_data = try_binary_strategy(pdf_data)
      pdf_data = try_base64_api_strategy(pdf_data)
      try_json_response_strategy(pdf_data)
    end

    def try_binary_strategy(pdf_data)
      return pdf_data if pdf_data[:base64].present?

      pdf_binary = fetch_pdf_binary_with_retries
      return pdf_data unless pdf_binary.present? && pdf_binary.start_with?('%PDF')

      {
        base64: Base64.strict_encode64(pdf_binary),
        download_url: pdf_data[:download_url]
      }.tap do |_result|
        Rails.logger.info("Successfully retrieved PDF binary (#{pdf_binary.length} bytes) and encoded to base64")
      end
    end

    def fetch_pdf_binary_with_retries
      3.times do |attempt|
        pdf_binary = invoices_client.get_pdf_binary(invoice_id)
        return pdf_binary if pdf_binary.present? && pdf_binary.start_with?('%PDF')
      rescue StandardError => e
        Rails.logger.warn("PDF binary fetch attempt #{attempt + 1} failed: #{e.message}")
        sleep(0.5) if attempt < 2
      end
      nil
    end

    def try_base64_api_strategy(pdf_data)
      return pdf_data if pdf_data[:base64].present?

      base64_data = invoices_client.get_pdf_as_base64(invoice_id)
      return pdf_data unless base64_data.present?

      Rails.logger.info("PDF base64 from JSON API length: #{base64_data.length}")
      { base64: base64_data, download_url: pdf_data[:download_url] }
    end

    def try_json_response_strategy(pdf_data)
      return pdf_data if pdf_data[:base64].present?

      pdf_data_response = invoices_client.get_pdf(invoice_id)
      log_pdf_data_response(pdf_data_response)

      base64_from_string = try_extract_base64_from_string(pdf_data_response)
      download_url = extract_download_url_if_hash(pdf_data_response)

      build_json_strategy_result(base64_from_string, download_url, pdf_data)
    end

    def log_pdf_data_response(pdf_data_response)
      response_preview = pdf_data_response.inspect[0..200]
      Rails.logger.info(
        "PDF data from FreshBooks API: #{pdf_data_response.class} - #{response_preview}"
      )
    end

    def extract_download_url_if_hash(pdf_data_response)
      return nil unless pdf_data_response.is_a?(Hash)

      extract_pdf_download_url(pdf_data_response)
    end

    def build_json_strategy_result(base64_from_string, download_url, pdf_data)
      {
        base64: base64_from_string || pdf_data[:base64],
        download_url: download_url || pdf_data[:download_url]
      }.tap do |result|
        Rails.logger.info("Extracted PDF download URL: #{result[:download_url].inspect}")
      end
    end

    def try_extract_base64_from_string(pdf_data)
      return nil unless pdf_data.is_a?(String) && pdf_data.length > 100

      decoded = Base64.decode64(pdf_data)
      pdf_data if decoded.start_with?('%PDF')
    rescue StandardError
      nil
    end

    def extract_pdf_download_url(pdf_data)
      return nil unless pdf_data.is_a?(Hash)

      try_pdf_url_keys(pdf_data)
    end

    def try_pdf_url_keys(pdf_data)
      direct_keys = ['file_url', :file_url, 'url', :url]
      direct_keys.each do |key|
        return pdf_data[key] if pdf_data[key].present?
      end

      nested_keys = [%w[pdf file_url], %w[pdf url]]
      nested_keys.each do |keys|
        url = pdf_data.dig(*keys)
        return url if url.present?
      end

      nil
    end

    def try_fallback(pdf_data)
      return pdf_data if pdf_data[:base64].present?

      fallback_base64 = try_binary_fallback
      fallback_url = extract_pdf_url unless fallback_base64.present?

      {
        base64: fallback_base64 || pdf_data[:base64],
        download_url: fallback_url || pdf_data[:download_url]
      }
    end

    def try_binary_fallback
      pdf_binary = invoices_client.get_pdf_binary(invoice_id)
      return nil unless pdf_binary.present? && pdf_binary.start_with?('%PDF')

      Base64.strict_encode64(pdf_binary).tap do
        Rails.logger.info('Successfully retrieved PDF via binary fallback method')
      end
    rescue StandardError => e
      Rails.logger.warn("Binary PDF fallback failed: #{e.message}")
      nil
    end

    def extract_pdf_url
      return nil unless invoice_data

      business_id = FreshbooksToken.current&.business_id || ENV.fetch('FRESHBOOKS_BUSINESS_ID', nil)
      invoice_id = invoice_data['id'] || invoice_data['invoiceid']
      return nil unless business_id && invoice_id

      "https://my.freshbooks.com/#/invoices/#{business_id}/#{invoice_id}/pdf"
    end
  end
end
