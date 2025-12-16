# frozen_string_literal: true

module Freshbooks
  class Invoices < BaseClient
    def list(page: 1, per_page: 100, client_id: nil)
      path = build_path('invoices/invoices')
      query = {
        page: page,
        per_page: per_page
      }
      query[:clientid] = client_id if client_id.present?

      response = make_request(:get, path, query: query)

      {
        invoices: response.dig('response', 'result', 'invoices') || [],
        page: response.dig('response', 'result', 'page') || page,
        pages: response.dig('response', 'result', 'pages') || 1,
        total: response.dig('response', 'result', 'total') || 0
      }
    end

    def get(invoice_id)
      path = build_path("invoices/invoices/#{invoice_id}")
      response = make_request(:get, path)
      response.dig('response', 'result', 'invoice')
    end

    def create(params)
      path = build_path('invoices/invoices')
      payload = build_invoice_payload(params)

      response = make_request(:post, path, body: payload.to_json)
      response.dig('response', 'result', 'invoice')
    end

    def update(invoice_id, params)
      path = build_path("invoices/invoices/#{invoice_id}")
      payload = build_invoice_payload(params)

      response = make_request(:put, path, body: payload.to_json)
      response.dig('response', 'result', 'invoice')
    end

    def send_by_email(invoice_id, email_params = {})
      endpoints = build_email_endpoints(invoice_id)
      payload = build_email_payload(email_params)

      result = try_email_endpoints(endpoints, payload)
      return result if result.present?

      return_manual_email_response
    end

    def build_email_endpoints(invoice_id)
      [
        "invoices/invoices/#{invoice_id}/email",
        "invoices/invoices/#{invoice_id}/send",
        "invoices/invoices/#{invoice_id}/send_email"
      ]
    end

    def build_email_payload(email_params)
      {
        email: {
          email: email_params[:email],
          subject: email_params[:subject],
          message: email_params[:message]
        }.compact
      }
    end

    def try_email_endpoints(endpoints, payload)
      endpoints.each do |endpoint_path|
        result = try_single_email_endpoint(endpoint_path, payload)
        return result if result.present?
      end
      nil
    end

    def try_single_email_endpoint(endpoint_path, payload)
      path = build_path(endpoint_path)
      Rails.logger.info("Attempting to send invoice email via: #{path}")
      response = make_request(:post, path, body: payload.to_json)
      result = response.dig('response', 'result')
      Rails.logger.info("Invoice email sent successfully via #{endpoint_path}")
      result if result.present?
    rescue FreshbooksError => e
      Rails.logger.warn("Endpoint #{endpoint_path} failed: #{e.message}")
      nil
    rescue StandardError => e
      Rails.logger.warn("Endpoint #{endpoint_path} error: #{e.message}")
      nil
    end

    def return_manual_email_response
      Rails.logger.warn('FreshBooks API does not support direct email sending via API')
      Rails.logger.info('Invoice email must be sent manually from FreshBooks UI')

      {
        success: true,
        method: 'manual_required',
        message: 'Invoice email must be sent manually from FreshBooks. Use the invoice link to access it.'
      }
    end

    def get_pdf(invoice_id)
      path = build_path("invoices/invoices/#{invoice_id}/pdf")

      # Try JSON API endpoint first (most common)
      begin
        response = make_request(:get, path)
        pdf_data = response.dig('response', 'result', 'pdf')

        # If PDF data is a string (base64), return it as-is
        # If it's a hash with file_url, return the hash
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

    def get_payment_link(invoice_id)
      invoice_data = get(invoice_id)
      return nil unless invoice_data

      invoice_data['payment_link'] ||
        invoice_data['payment_url'] ||
        build_payment_url_from_invoice(invoice_data)
    end

    private

    def build_invoice_payload(params)
      payload = { invoice: build_invoice_attributes(params) }
      add_status_if_present(payload, params)
      payload
    end

    def build_invoice_attributes(params)
      {
        customerid: extract_customer_id(params),
        create_date: extract_create_date(params),
        due_date: params[:due_date],
        currency_code: extract_currency_code(params),
        notes: params[:notes],
        terms: params[:terms],
        tax_included: params[:tax_included] || 'yes',
        tax_calculation: params[:tax_calculation] || 'item',
        lines: build_lines(params[:lines] || [])
      }.compact
    end

    def extract_customer_id(params)
      params[:client_id] || params[:customerid]
    end

    def extract_create_date(params)
      params[:date] || Date.current.to_s
    end

    def extract_currency_code(params)
      params[:currency] || params[:currency_code] || 'USD'
    end

    def add_status_if_present(payload, params)
      payload[:invoice][:status] = params[:status] if params[:status].present?
    end

    def build_lines(lines_data)
      lines_data.map { |line| build_single_line(line) }
    end

    def build_single_line(line)
      line_item = build_base_line_item(line)
      apply_tax_settings(line_item, line)
      line_item.compact
    end

    def build_base_line_item(line)
      {
        name: line[:name],
        description: line[:description],
        qty: extract_quantity(line),
        unit_cost: build_unit_cost(line),
        type: line[:type] || 0
      }
    end

    def extract_quantity(line)
      line[:quantity] || line[:qty] || 1
    end

    def build_unit_cost(line)
      {
        amount: line[:cost] || line[:unit_cost],
        code: line[:currency] || 'USD'
      }
    end

    def apply_tax_settings(line_item, line)
      if tax_included?(line)
        zero_tax_amounts(line_item)
      elsif line[:tax_amount1].present?
        set_custom_tax_amounts(line_item, line)
      end
    end

    def tax_included?(line)
      [true, 'yes'].include?(line[:tax_included])
    end

    def zero_tax_amounts(line_item)
      line_item[:tax_amount1] = '0'
      line_item[:tax_amount2] = '0'
    end

    def set_custom_tax_amounts(line_item, line)
      line_item[:tax_amount1] = line[:tax_amount1]
      line_item[:tax_amount2] = line[:tax_amount2] if line[:tax_amount2].present?
    end

    def build_payment_url_from_invoice(invoice_data)
      business_id = FreshbooksToken.current&.business_id || ENV.fetch('FRESHBOOKS_BUSINESS_ID', nil)
      invoice_id = invoice_data['id'] || invoice_data['invoiceid']
      return nil unless business_id && invoice_id

      "https://my.freshbooks.com/view/#{business_id}/#{invoice_id}"
    end
  end
end
