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

    # Use lifecycle service for bulletproof payment handling
    lifecycle_service = Freshbooks::InvoiceLifecycleService.new(freshbooks_invoice)
    lifecycle_service.handle_payment_received(payment_data)

    # Also trigger a full invoice sync to ensure everything is in sync
    Freshbooks::SyncInvoicesJob.perform_later(invoice_id)

    Rails.logger.info "Payment webhook processed for invoice #{invoice_id}"
  rescue FreshbooksError => e
    Rails.logger.error "Failed to fetch payment #{payment_id}: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Payment webhook error: #{e.message}\n#{e.backtrace.join("\n")}"
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


  def handle_invoice_webhook_by_id(invoice_id)
    return unless invoice_id

    # Use lifecycle service for bulletproof invoice sync
    freshbooks_invoice = FreshbooksInvoice.find_by(freshbooks_id: invoice_id)
    return unless freshbooks_invoice

    lifecycle_service = Freshbooks::InvoiceLifecycleService.new(freshbooks_invoice)
    lifecycle_service.sync_from_freshbooks

    Rails.logger.info "Invoice webhook processed: #{invoice_id}"
  rescue FreshbooksError => e
    Rails.logger.error "Failed to fetch invoice #{invoice_id}: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "Invoice webhook error: #{e.message}\n#{e.backtrace.join("\n")}"
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

  def normalize_status(status)
    return nil if status.blank?

    # Convert numeric status to string for database consistency
    InvoiceStatusConverter.to_string_safe(status) || status.to_s
  end
end
