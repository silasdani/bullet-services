# frozen_string_literal: true

module Freshbooks
  class SyncPaymentsJob < ApplicationJob
    queue_as :default

    retry_on FreshbooksError, wait: ->(executions) { (2**executions) + 1 }, attempts: 3
    discard_on ActiveRecord::RecordNotFound

    def perform(payment_id = nil)
      payments_service = Freshbooks::Payments.new

      if payment_id
        sync_single_payment(payments_service, payment_id)
      else
        sync_all_payments(payments_service)
      end
    end

    private

    def sync_single_payment(payments_service, payment_id)
      payment_data = payments_service.get(payment_id)
      return unless payment_data

      create_or_update_payment(payment_data)
      reconcile_invoice_for_payment(payment_data)
    end

    def sync_all_payments(payments_service)
      page = 1
      errors = []

      loop do
        result = payments_service.list(page: page, per_page: 100)
        errors.concat(sync_payment_page(result[:payments]))

        break if page >= result[:pages]

        page += 1
      end

      log_sync_errors(errors)
    end

    def sync_payment_page(payments)
      errors = []
      payments.each do |payment_data|
        create_or_update_payment(payment_data)
        reconcile_invoice_for_payment(payment_data)
      rescue StandardError => e
        payment_id = payment_data['id']
        error_msg = "Payment #{payment_id}: #{e.message}"
        errors << error_msg
        Rails.logger.error("Failed to sync payment #{payment_id}: #{e.message}")
      end
      errors
    end

    def log_sync_errors(errors)
      return unless errors.any?

      Rails.logger.warn("Payment sync completed with #{errors.length} errors")
    end

    def create_or_update_payment(payment_data)
      payment = FreshbooksPayment.find_or_initialize_by(freshbooks_id: payment_data['id'])
      payment.assign_attributes(
        freshbooks_invoice_id: payment_data['invoiceid'],
        amount: extract_amount(payment_data['amount']),
        date: parse_date(payment_data['date']),
        payment_method: payment_data['type'],
        currency_code: payment_data.dig('amount', 'code'),
        notes: payment_data['notes'],
        raw_data: payment_data
      )
      payment.save!
      payment
    end

    def reconcile_invoice_for_payment(payment_data)
      invoice_id = payment_data['invoiceid']
      return unless invoice_id

      freshbooks_invoice = FreshbooksInvoice.find_by(freshbooks_id: invoice_id)
      return unless freshbooks_invoice

      # Use lifecycle service to reconcile invoice status based on payments
      lifecycle_service = Freshbooks::InvoiceLifecycleService.new(freshbooks_invoice)
      lifecycle_service.reconcile_payments
      lifecycle_service.propagate_status_to_invoice
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
end
