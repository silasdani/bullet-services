# frozen_string_literal: true

module Freshbooks
  class Payments < BaseClient
    def list(page: 1, per_page: 100, invoice_id: nil, client_id: nil)
      path = build_path('payments/payments')
      query = {
        page: page,
        per_page: per_page
      }
      query[:invoiceid] = invoice_id if invoice_id.present?
      query[:clientid] = client_id if client_id.present?

      response = make_request(:get, path, query: query)

      {
        payments: response.dig('response', 'result', 'payments') || [],
        page: response.dig('response', 'result', 'page') || page,
        pages: response.dig('response', 'result', 'pages') || 1,
        total: response.dig('response', 'result', 'total') || 0
      }
    end

    def get(payment_id)
      path = build_path("payments/payments/#{payment_id}")
      response = make_request(:get, path)
      response.dig('response', 'result', 'payment')
    end

    def create(params)
      path = build_path('payments/payments')
      payload = {
        payment: {
          invoiceid: params[:invoice_id],
          amount: {
            amount: params[:amount].to_s,
            code: params[:currency] || 'USD'
          },
          date: params[:date] || Date.current.to_s,
          type: params[:payment_method] || 'Check',
          notes: params[:notes]
        }.compact
      }

      response = make_request(:post, path, body: payload.to_json)
      response.dig('response', 'result', 'payment')
    end

    def update(payment_id, params)
      path = build_path("payments/payments/#{payment_id}")
      payload = {
        payment: params.slice(:amount, :date, :type, :notes).compact
      }

      response = make_request(:put, path, body: payload.to_json)
      response.dig('response', 'result', 'payment')
    end

    def delete?(payment_id)
      path = build_path("payments/payments/#{payment_id}")
      make_request(:delete, path)
      true
    end
  end
end
