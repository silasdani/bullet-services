# frozen_string_literal: true

module FreshbooksWebhookHandling
  extend ActiveSupport::Concern

  private

  def handle_payment_webhook_by_id(payment_id)
    return unless payment_id

    payment_data = fetch_payment_data(payment_id)
    return unless payment_data

    invoice_id = extract_invoice_id(payment_data)
    freshbooks_invoice = find_freshbooks_invoice(invoice_id)
    return unless freshbooks_invoice

    update_invoice_status(freshbooks_invoice)
    create_or_update_payment(payment_id, invoice_id, payment_data)

    Rails.logger.info "Payment processed for invoice #{invoice_id}"
  rescue FreshbooksError => e
    Rails.logger.error "Failed to fetch payment #{payment_id}: #{e.message}"
  end

  def fetch_payment_data(payment_id)
    payments = Freshbooks::Payments.new
    payments.get(payment_id)
  end

  def extract_invoice_id(payment_data)
    payment_data['invoiceid'] || payment_data.dig('invoice', 'id')
  end

  def find_freshbooks_invoice(invoice_id)
    FreshbooksInvoice.find_by(freshbooks_id: invoice_id)
  end

  def update_invoice_status(freshbooks_invoice)
    freshbooks_invoice.update!(
      status: 'paid',
      amount_outstanding: 0
    )

    freshbooks_invoice.invoice&.update!(
      final_status: 'paid',
      status: 'paid'
    )
  end

  def create_or_update_payment(payment_id, invoice_id, payment_data)
    FreshbooksPayment.find_or_create_by(freshbooks_id: payment_id) do |payment|
      payment.freshbooks_invoice_id = invoice_id
      payment.amount = extract_amount(payment_data['amount'])
      payment.date = parse_date(payment_data['date'])
      payment.payment_method = payment_data['type']
      payment.currency_code = payment_data.dig('amount', 'code')
      payment.raw_data = payment_data
    end
  end

  def handle_invoice_webhook_by_id(invoice_id)
    return unless invoice_id

    # Fetch invoice details from FreshBooks API
    begin
      invoices = Freshbooks::Invoices.new
      invoice_data = invoices.get(invoice_id)
      return unless invoice_data

      # Update local invoice record if it exists
      freshbooks_invoice = FreshbooksInvoice.find_by(freshbooks_id: invoice_id)
      return unless freshbooks_invoice

      freshbooks_invoice.update!(
        status: invoice_data['status'] || invoice_data['v3_status'],
        amount_outstanding: extract_amount(invoice_data['outstanding'] || invoice_data['amount_outstanding']),
        raw_data: invoice_data
      )

      Rails.logger.info "Invoice updated: #{invoice_id}"
    rescue FreshbooksError => e
      Rails.logger.error "Failed to fetch invoice #{invoice_id}: #{e.message}"
    end
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
end
