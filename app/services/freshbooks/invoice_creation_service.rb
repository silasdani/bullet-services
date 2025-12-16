# frozen_string_literal: true

module Freshbooks
  class InvoiceCreationService < ApplicationService
    attribute :invoice
    attribute :client_id, :string
    attribute :lines, default: -> { [] }
    attribute :send_email, :boolean, default: -> { false }
    attribute :email_to, :string

    def call
      return add_error('Invoice is required') if invoice.nil?
      return add_error('Client ID is required') if client_id.blank?

      with_error_handling do
        create_freshbooks_invoice
        send_invoice_email if send_email && email_to.present?
      end
    end

    private

    def create_freshbooks_invoice
      invoices_client = Freshbooks::Invoices.new

      invoice_params = build_invoice_params
      freshbooks_invoice_data = invoices_client.create(invoice_params)

      freshbooks_invoice_id = freshbooks_invoice_data['id'] || freshbooks_invoice_data['invoiceid']
      invoice_url = extract_invoice_url(freshbooks_invoice_data)

      pdf_data = fetch_invoice_pdf_data(invoices_client, freshbooks_invoice_id, freshbooks_invoice_data)

      update_invoice_and_sync_record(freshbooks_invoice_data, invoice_url, freshbooks_invoice_id)

      @result = {
        freshbooks_invoice: freshbooks_invoice_data,
        invoice: invoice,
        pdf_url: pdf_data[:download_url],
        pdf_base64: pdf_data[:base64],
        invoice_url: invoice_url
      }
    end

    def fetch_invoice_pdf_data(invoices_client, invoice_id, invoice_data)
      pdf_data = { base64: nil, download_url: nil }

      pdf_data = try_primary_pdf_strategies(invoices_client, invoice_id, pdf_data)
      try_pdf_fallback(invoices_client, invoice_id, invoice_data, pdf_data)
    rescue StandardError => e
      log_error("Failed to get PDF from FreshBooks API: #{e.message}")
      log_error("Error class: #{e.class}")
      log_error("Error backtrace: #{e.backtrace.first(5).join('\n')}")
      pdf_data
    end

    def try_primary_pdf_strategies(invoices_client, invoice_id, pdf_data)
      pdf_data = try_binary_pdf_strategy(invoices_client, invoice_id, pdf_data)
      pdf_data = try_base64_api_strategy(invoices_client, invoice_id, pdf_data)
      try_json_response_strategy(invoices_client, invoice_id, pdf_data)
    end

    def try_binary_pdf_strategy(invoices_client, invoice_id, pdf_data)
      return pdf_data if pdf_data[:base64].present?

      pdf_binary = fetch_pdf_binary_with_retries(invoices_client, invoice_id)
      return pdf_data unless pdf_binary.present? && pdf_binary.start_with?('%PDF')

      {
        base64: Base64.strict_encode64(pdf_binary),
        download_url: pdf_data[:download_url]
      }.tap do |_result|
        log_info("Successfully retrieved PDF binary (#{pdf_binary.length} bytes) and encoded to base64")
      end
    end

    def fetch_pdf_binary_with_retries(invoices_client, invoice_id)
      3.times do |attempt|
        pdf_binary = invoices_client.get_pdf_binary(invoice_id)
        return pdf_binary if pdf_binary.present? && pdf_binary.start_with?('%PDF')
      rescue StandardError => e
        log_warn("PDF binary fetch attempt #{attempt + 1} failed: #{e.message}")
        sleep(0.5) if attempt < 2
      end
      nil
    end

    def try_base64_api_strategy(invoices_client, invoice_id, pdf_data)
      return pdf_data if pdf_data[:base64].present?

      base64_data = invoices_client.get_pdf_as_base64(invoice_id)
      return pdf_data unless base64_data.present?

      log_info("PDF base64 from JSON API length: #{base64_data.length}")
      { base64: base64_data, download_url: pdf_data[:download_url] }
    end

    def try_json_response_strategy(invoices_client, invoice_id, pdf_data)
      return pdf_data if pdf_data[:base64].present?

      pdf_data_response = invoices_client.get_pdf(invoice_id)
      log_info("PDF data from FreshBooks API: #{pdf_data_response.class} - #{pdf_data_response.inspect[0..200]}")

      base64_from_string = try_extract_base64_from_string(pdf_data_response)
      download_url = extract_pdf_download_url(pdf_data_response) if pdf_data_response.is_a?(Hash)

      {
        base64: base64_from_string || pdf_data[:base64],
        download_url: download_url || pdf_data[:download_url]
      }.tap do |result|
        log_info("Extracted PDF download URL: #{result[:download_url].inspect}")
      end
    end

    def try_extract_base64_from_string(pdf_data)
      return nil unless pdf_data.is_a?(String) && pdf_data.length > 100

      decoded = Base64.decode64(pdf_data)
      pdf_data if decoded.start_with?('%PDF')
    rescue StandardError
      nil
    end

    def try_pdf_fallback(invoices_client, invoice_id, invoice_data, pdf_data)
      return pdf_data if pdf_data[:base64].present?

      fallback_base64 = try_binary_fallback(invoices_client, invoice_id)
      fallback_url = extract_pdf_url(invoice_data) unless fallback_base64.present?

      {
        base64: fallback_base64 || pdf_data[:base64],
        download_url: fallback_url || pdf_data[:download_url]
      }
    end

    def try_binary_fallback(invoices_client, invoice_id)
      pdf_binary = invoices_client.get_pdf_binary(invoice_id)
      return nil unless pdf_binary.present? && pdf_binary.start_with?('%PDF')

      Base64.strict_encode64(pdf_binary).tap do
        log_info('Successfully retrieved PDF via binary fallback method')
      end
    rescue StandardError => e
      log_warn("Binary PDF fallback failed: #{e.message}")
      nil
    end

    def update_invoice_and_sync_record(freshbooks_invoice_data, invoice_url, invoice_id)
      invoice.update!(
        freshbooks_client_id: client_id,
        invoice_pdf_link: invoice_url
      )

      sync_freshbooks_invoice_record(freshbooks_invoice_data, invoice_url)
      log_info("Created FreshBooks invoice #{invoice_id} for invoice #{invoice.id}")
    end

    def build_invoice_params
      {
        client_id: client_id,
        date: invoice.created_at&.to_date || Date.current,
        currency: 'USD',
        notes: build_notes,
        tax_included: 'yes', # VAT is already included in the price
        tax_calculation: 'item',
        lines: build_invoice_lines
      }
    end

    def build_invoice_lines
      return lines if lines.any?

      [build_default_invoice_line]
    end

    def build_default_invoice_line
      {
        name: invoice.name || 'Invoice',
        description: build_line_description,
        quantity: 1,
        cost: determine_line_cost,
        type: 0, # Service
        tax_included: invoice.included_vat_amount.present?
      }
    end

    def build_line_description
      invoice.job || invoice.wrs_link || ''
    end

    def determine_line_cost
      invoice.included_vat_amount || invoice.excluded_vat_amount || 0
    end

    def build_notes
      notes = []
      notes << "Job: #{invoice.job}" if invoice.job.present?
      notes << "WRS Link: #{invoice.wrs_link}" if invoice.wrs_link.present?
      notes.join("\n")
    end

    def calculate_due_date
      # Default to 30 days from invoice date
      (invoice.created_at&.to_date || Date.current) + 30.days
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

    def extract_pdf_url(freshbooks_data)
      # Direct FreshBooks PDF download URL (fallback)
      business_id = FreshbooksToken.current&.business_id || ENV.fetch('FRESHBOOKS_BUSINESS_ID', nil)
      invoice_id = freshbooks_data['id'] || freshbooks_data['invoiceid']
      return nil unless business_id && invoice_id

      "https://my.freshbooks.com/#/invoices/#{business_id}/#{invoice_id}/pdf"
    end

    def extract_invoice_url(freshbooks_data)
      # FreshBooks UI invoice URL (desired format)
      business_id = FreshbooksToken.current&.business_id || ENV.fetch('FRESHBOOKS_BUSINESS_ID', nil)
      invoice_id = freshbooks_data['id'] || freshbooks_data['invoiceid']
      return nil unless business_id && invoice_id

      "https://my.freshbooks.com/#/invoice/#{business_id}-#{invoice_id}"
    end

    def sync_freshbooks_invoice_record(freshbooks_data, invoice_url = nil)
      fb_invoice = find_or_initialize_fb_invoice(freshbooks_data)
      assign_fb_invoice_attributes(fb_invoice, freshbooks_data, invoice_url)
      fb_invoice.save!
    end

    def find_or_initialize_fb_invoice(freshbooks_data)
      invoice_id = freshbooks_data['id'] || freshbooks_data['invoiceid']
      FreshbooksInvoice.find_or_initialize_by(freshbooks_id: invoice_id)
    end

    def assign_fb_invoice_attributes(fb_invoice, freshbooks_data, invoice_url = nil)
      fb_invoice.assign_attributes(
        **build_fb_invoice_basic_attributes(freshbooks_data),
        **build_fb_invoice_financial_attributes(freshbooks_data),
        **build_fb_invoice_metadata(freshbooks_data, invoice_url)
      )
    end

    def build_fb_invoice_basic_attributes(freshbooks_data)
      {
        freshbooks_client_id: client_id,
        invoice_number: freshbooks_data['invoice_number'],
        status: freshbooks_data['status'] || freshbooks_data['v3_status'],
        notes: freshbooks_data['notes'],
        invoice_id: invoice.id
      }
    end

    def build_fb_invoice_financial_attributes(freshbooks_data)
      {
        amount: extract_amount(freshbooks_data['amount']),
        amount_outstanding: extract_amount(freshbooks_data['outstanding'] || freshbooks_data['amount_outstanding']),
        currency_code: freshbooks_data.dig('amount', 'code') || freshbooks_data['currency_code']
      }
    end

    def build_fb_invoice_metadata(freshbooks_data, invoice_url = nil)
      {
        date: parse_date(freshbooks_data['create_date'] || freshbooks_data['date']),
        due_date: parse_date(freshbooks_data['due_date']),
        pdf_url: invoice_url || extract_invoice_url(freshbooks_data),
        raw_data: freshbooks_data
      }
    end

    def extract_amount(amount_data)
      return nil unless amount_data

      amount_data.is_a?(Hash) ? amount_data['amount'].to_d : amount_data.to_d
    end

    def parse_date(date_string)
      return nil unless date_string

      Date.parse(date_string)
    rescue ArgumentError
      nil
    end

    def send_invoice_email
      invoices_client = Freshbooks::Invoices.new
      freshbooks_invoice_id = @result[:freshbooks_invoice]['id'] || @result[:freshbooks_invoice]['invoiceid']

      invoices_client.send_by_email(
        freshbooks_invoice_id,
        email: email_to,
        subject: "Invoice #{invoice.name || invoice.slug}",
        message: 'Please find your invoice attached. You can pay online using your FreshBooks client portal.'
      )

      log_info("Sent invoice email to #{email_to} for FreshBooks invoice #{freshbooks_invoice_id}")
    end
  end
end
