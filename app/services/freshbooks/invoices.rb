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
      # Try multiple possible endpoints - FreshBooks API endpoint structure may vary
      endpoints_to_try = [
        "invoices/invoices/#{invoice_id}/email",
        "invoices/invoices/#{invoice_id}/send",
        "invoices/invoices/#{invoice_id}/send_email"
      ]

      payload = {
        email: {
          email: email_params[:email],
          subject: email_params[:subject],
          message: email_params[:message]
        }.compact
      }

      last_error = nil
      endpoints_to_try.each do |endpoint_path|
        path = build_path(endpoint_path)
        Rails.logger.info("Attempting to send invoice email via: #{path}")
        response = make_request(:post, path, body: payload.to_json)
        result = response.dig('response', 'result')
        Rails.logger.info("Invoice email sent successfully via #{endpoint_path}")
        return result if result.present?
      rescue FreshbooksError => e
        last_error = e
        Rails.logger.warn("Endpoint #{endpoint_path} failed: #{e.message}")
        # Continue to next endpoint
      rescue StandardError => e
        last_error = e
        Rails.logger.warn("Endpoint #{endpoint_path} error: #{e.message}")
        # Continue to next endpoint
      end

      # FreshBooks API doesn't have a direct email endpoint
      # Return a helpful response indicating manual send is required
      Rails.logger.warn('FreshBooks API does not support direct email sending via API')
      Rails.logger.info('Invoice email must be sent manually from FreshBooks UI')

      # Return success with a note that manual action is required
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
      # Try to get PDF as base64 directly from API
      path = build_path("invoices/invoices/#{invoice_id}/pdf")

      # First try raw binary PDF and convert to base64
      begin
        pdf_bytes = get_pdf_binary(invoice_id)
        return Base64.strict_encode64(pdf_bytes) if pdf_bytes.present? && pdf_bytes.start_with?('%PDF')
      rescue StandardError => e
        Rails.logger.warn("Binary PDF fetch failed: #{e.message}")
      end

      # Fallback to JSON API response
      response = make_request(:get, path)

      # Check if response contains base64 PDF data
      pdf_data = response.dig('response', 'result', 'pdf')
      return pdf_data if pdf_data.is_a?(String) && pdf_data.length > 100

      # Check nested structure
      pdf_data = response.dig('response', 'result', 'pdf', 'content') ||
                 response.dig('response', 'result', 'pdf', 'data') ||
                 response.dig('response', 'result', 'content') ||
                 response.dig('response', 'result', 'pdf', 'base64')

      pdf_data if pdf_data.is_a?(String) && pdf_data.length > 100
    end

    def get_pdf_binary(invoice_id)
      # Get PDF as raw binary bytes using HTTParty directly
      path = build_path("invoices/invoices/#{invoice_id}/pdf")
      full_url = "#{self.class.base_uri}#{path}"

      token = FreshbooksToken.current
      unless token
        Rails.logger.error('No FreshBooks token available for PDF download')
        return nil
      end

      options = {
        headers: {
          'Authorization' => "Bearer #{token.access_token}",
          'Api-Version' => 'alpha',
          'Accept' => 'application/pdf'
        }
      }

      Rails.logger.info("Attempting to fetch PDF binary from: #{full_url}")
      response = HTTParty.get(full_url, options)

      Rails.logger.info("PDF binary response code: #{response.code}, content-type: #{response.headers['content-type']}, body length: #{response.body&.length}")

      if response.success? && response.body.present?
        # Check if it's actually PDF
        body_start = begin
          response.body[0..10]
        rescue StandardError
          ''
        end
        Rails.logger.info("PDF body starts with: #{body_start.inspect}")

        if response.body.start_with?('%PDF')
          Rails.logger.info("Successfully retrieved PDF binary (#{response.body.length} bytes)")
          return response.body
        elsif response.headers['content-type']&.include?('application/pdf')
          Rails.logger.info('Content-type indicates PDF, returning body')
          return response.body
        else
          Rails.logger.warn("Response doesn't appear to be PDF. Starts with: #{body_start.inspect}")
        end
      else
        Rails.logger.warn("PDF request failed: code=#{response.code}, body=#{response.body[0..200]}")
      end

      nil
    rescue StandardError => e
      Rails.logger.error("Failed to get PDF binary: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.first(5).join('\n')}")
      nil
    end

    def get_payment_link(invoice_id)
      invoice_data = get(invoice_id)
      return nil unless invoice_data

      # FreshBooks provides payment URLs in the response
      # Check for payment_link, payment_url, or construct from invoice data
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
        customerid: params[:client_id] || params[:customerid],
        create_date: params[:date] || Date.current.to_s,
        due_date: params[:due_date],
        currency_code: params[:currency] || params[:currency_code] || 'USD',
        notes: params[:notes],
        terms: params[:terms],
        tax_included: params[:tax_included] || 'yes', # Default to VAT-inclusive pricing
        tax_calculation: params[:tax_calculation] || 'item',
        lines: build_lines(params[:lines] || [])
      }.compact
    end

    def add_status_if_present(payload, params)
      payload[:invoice][:status] = params[:status] if params[:status].present?
    end

    def build_lines(lines_data)
      lines_data.map do |line|
        line_item = {
          name: line[:name],
          description: line[:description],
          qty: line[:quantity] || line[:qty] || 1,
          unit_cost: {
            amount: line[:cost] || line[:unit_cost],
            code: line[:currency] || 'USD'
          },
          type: line[:type] || 0 # 0 = service, 1 = product
        }

        # If tax_included is set, ensure line items don't add additional tax
        # Set tax_amount1 to 0 to explicitly tell FreshBooks no additional VAT
        if [true, 'yes'].include?(line[:tax_included])
          line_item[:tax_amount1] = '0'
          line_item[:tax_amount2] = '0'
        elsif line[:tax_amount1].present?
          line_item[:tax_amount1] = line[:tax_amount1]
          line_item[:tax_amount2] = line[:tax_amount2] if line[:tax_amount2].present?
        end

        line_item.compact
      end
    end

    def build_payment_url_from_invoice(invoice_data)
      # FreshBooks payment URL format
      # Format: https://my.freshbooks.com/view/{business_id}/{invoice_id}
      business_id = FreshbooksToken.current&.business_id || ENV.fetch('FRESHBOOKS_BUSINESS_ID', nil)
      invoice_id = invoice_data['id'] || invoice_data['invoiceid']
      return nil unless business_id && invoice_id

      "https://my.freshbooks.com/view/#{business_id}/#{invoice_id}"
    end
  end
end
