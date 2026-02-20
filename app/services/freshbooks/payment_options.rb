# frozen_string_literal: true

# FreshBooks Online Payments API - enables "Pay Invoice" in invoice emails
# See: https://www.freshbooks.com/api/enabling-online-payments
# Requires scopes: user:online_payments:read, user:online_payments:write
module Freshbooks
  class PaymentOptions < BaseClient
    # Get default payment options (available gateway for account)
    def list(entity_type: 'invoice')
      path = payments_path('payment_options')
      response = make_request(:get, path, query: { entity_type: entity_type })
      response['payment_options']
    end

    # Get payment options for a specific invoice
    def get_for_invoice(invoice_id)
      path = payments_path("invoice/#{invoice_id}/payment_options")
      response = make_request(:get, path)
      response['payment_options']
    end

    # Enable online payments on an invoice
    # This makes FreshBooks show "Pay Invoice" instead of just "View Invoice"
    # Per docs: https://www.freshbooks.com/api/enabling-online-payments
    def enable_for_invoice(invoice_id, gateway_name: 'stripe', has_credit_card: true)
      path = payments_path("invoice/#{invoice_id}/payment_options")
      payload = { gateway_name: gateway_name, has_credit_card: has_credit_card }
      response = make_request(:post, path, body: payload.to_json)
      response['payment_options']
    end

    private

    def payments_path(endpoint)
      "/payments/account/#{business_id}/#{endpoint}"
    end
  end
end
