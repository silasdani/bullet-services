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
        due_date: extract_due_date(params),
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

    def extract_due_date(params)
      return nil unless params[:due_date].present?

      # Convert Date object to string format expected by FreshBooks API
      due_date = params[:due_date]
      due_date.is_a?(Date) ? due_date.to_s : due_date.to_s
    end

    def extract_currency_code(params)
      params[:currency] || params[:currency_code] || 'USD'
    end

    def add_status_if_present(payload, params)
      return unless params[:status].present?

      numeric_status = InvoiceStatusConverter.to_numeric(params[:status])

      # FreshBooks API doesn't allow setting status to 'void' (5) via update endpoint
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
