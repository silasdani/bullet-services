# frozen_string_literal: true

module Freshbooks
  class Invoices < BaseClient
    include Freshbooks::InvoicePdfMethods
    include Freshbooks::InvoiceEmailMethods
    include Freshbooks::InvoiceLineBuilder
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

    def get(invoice_id, includes: [])
      path = build_path("invoices/invoices/#{invoice_id}")
      query = includes.any? ? { 'include[]' => includes } : {}
      response = make_request(:get, path, query: query)
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
      payload = build_invoice_payload(params, is_update: true)

      response = make_request(:put, path, body: payload.to_json)
      response.dig('response', 'result', 'invoice')
    end

    def get_payment_link(invoice_id)
      invoice_data = get(invoice_id)
      return nil unless invoice_data

      invoice_data['payment_link'] ||
        invoice_data['payment_url'] ||
        build_payment_url_from_invoice(invoice_data)
    end

    def void(invoice_id)
      path = build_path("invoices/invoices/#{invoice_id}")
      # FreshBooks voids invoices by setting vis_state to 1 (0 = active, 1 = deleted/voided)
      payload = { invoice: { vis_state: 1 } }

      response = make_request(:put, path, body: payload.to_json)
      response.dig('response', 'result', 'invoice')
    end

    private

    def build_invoice_payload(params, is_update: false)
      payload = { invoice: build_invoice_attributes(params, is_update: is_update) }
      add_status_if_present(payload, params)
      payload
    end

    def build_invoice_attributes(params, is_update: false)
      attributes = build_base_attributes(params)
      add_optional_attributes(attributes, params, is_update)
      attributes.compact
    end

    def build_base_attributes(params)
      {
        customerid: extract_customer_id(params),
        create_date: extract_create_date(params),
        currency_code: extract_currency_code(params),
        notes: params[:notes],
        terms: params[:terms],
        tax_included: params[:tax_included] || 'yes',
        tax_calculation: params[:tax_calculation] || 'item',
        lines: build_lines(params[:lines] || []),
        action_email: params[:action_email],
        email_recipients: params[:email_recipients],
        email_include_pdf: params[:email_include_pdf]
      }
    end

    def add_optional_attributes(attributes, params, is_update)
      attributes[:discount_value] = params[:discount_value] if params[:discount_value].present?
      attributes[:due_date] = extract_due_date(params) unless is_update
    end

    def extract_customer_id(params)
      params[:client_id] || params[:customerid]
    end

    def extract_create_date(params)
      params[:date] || Date.current.to_s
    end

    def extract_due_date(params)
      return nil unless params[:due_date].present?

      # Convert Date object to string format expected by FreshBooks API
      params[:due_date].to_s
    end

    def extract_currency_code(params)
      params[:currency] || params[:currency_code] || 'GBP'
    end

    def add_status_if_present(payload, params)
      return unless params[:status].present?

      numeric_status = InvoiceStatusConverter.to_numeric(params[:status])

      # FreshBooks API doesn't allow setting status to 'void' (5) via status field
      # Use the void() method with action_mark_as_void instead
      # Status can only be set to: 'draft', 'sent', 'viewed', or 'disputed'
      return if numeric_status == InvoiceStatusConverter::VOID

      payload[:invoice][:status] = numeric_status
    end

    def build_payment_url_from_invoice(invoice_data)
      business_id = FreshbooksToken.current&.business_id || ENV.fetch('FRESHBOOKS_BUSINESS_ID', nil)
      invoice_id = invoice_data['id'] || invoice_data['invoiceid']
      return nil unless business_id && invoice_id

      "https://my.freshbooks.com/view/#{business_id}/#{invoice_id}"
    end
  end
end
