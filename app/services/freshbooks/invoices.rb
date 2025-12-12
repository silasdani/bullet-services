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
      path = build_path("invoices/invoices/#{invoice_id}/email")
      payload = {
        email: {
          email: email_params[:email],
          subject: email_params[:subject],
          message: email_params[:message]
        }.compact
      }

      response = make_request(:post, path, body: payload.to_json)
      response.dig('response', 'result')
    end

    def get_pdf(invoice_id)
      path = build_path("invoices/invoices/#{invoice_id}/pdf")
      response = make_request(:get, path)
      response.dig('response', 'result', 'pdf')
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
        lines: build_lines(params[:lines] || [])
      }.compact
    end

    def add_status_if_present(payload, params)
      payload[:invoice][:status] = params[:status] if params[:status].present?
    end

    def build_lines(lines_data)
      lines_data.map do |line|
        {
          name: line[:name],
          description: line[:description],
          qty: line[:quantity] || line[:qty] || 1,
          unit_cost: {
            amount: line[:cost] || line[:unit_cost],
            code: line[:currency] || 'USD'
          },
          type: line[:type] || 0 # 0 = service, 1 = product
        }.compact
      end
    end

    # Get payment link for invoice (public payment URL)
    def get_payment_link(invoice_id)
      invoice_data = get(invoice_id)
      return nil unless invoice_data

      # FreshBooks provides payment URLs in the response
      # Check for payment_link, payment_url, or construct from invoice data
      invoice_data['payment_link'] ||
        invoice_data['payment_url'] ||
        build_payment_url_from_invoice(invoice_data)
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
