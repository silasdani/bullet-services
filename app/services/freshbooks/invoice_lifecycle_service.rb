# frozen_string_literal: true

module Freshbooks
  # Central service for managing FreshBooks invoice lifecycle and ensuring data consistency
  # This service ensures that invoice status, payments, and related records stay in sync
  # rubocop:disable Metrics/ClassLength
  class InvoiceLifecycleService
    attr_reader :freshbooks_invoice, :errors

    def initialize(freshbooks_invoice)
      @freshbooks_invoice = freshbooks_invoice
      @errors = []
    end

    # Sync invoice from FreshBooks API and reconcile all related data
    def sync_from_freshbooks
      return add_error('FreshBooks invoice not found') unless freshbooks_invoice

      invoice_data = fetch_invoice_data
      return false unless invoice_data

      sync_invoice_with_data(invoice_data)
    rescue StandardError => e
      handle_sync_error(e)
      false
    end

    def fetch_invoice_data
      invoices_service = Freshbooks::Invoices.new
      invoice_data = invoices_service.get(freshbooks_invoice.freshbooks_id)
      return invoice_data if invoice_data

      add_error('Failed to fetch invoice from FreshBooks')
      nil
    end

    # rubocop:disable Naming/PredicateMethod
    # This method syncs data but is not a predicate
    def sync_invoice_with_data(invoice_data)
      ActiveRecord::Base.transaction do
        update_invoice_from_freshbooks_data(invoice_data)
        reconcile_payments
        propagate_status_to_invoice
      end
      true
    end
    # rubocop:enable Naming/PredicateMethod

    def handle_sync_error(error)
      add_error("Sync failed: #{error.message}")
      Rails.logger.error("InvoiceLifecycleService sync error: #{error.message}\n#{error.backtrace.join("\n")}")
    end

    # Reconcile invoice status based on payments
    def reconcile_payments
      return unless freshbooks_invoice

      invoice_amount, total_paid = calculate_payment_totals
      outstanding = invoice_amount - total_paid
      new_status = determine_status_from_payments(invoice_amount, total_paid, outstanding)
      update_invoice_if_changed(new_status, outstanding)
    end

    def calculate_payment_totals
      payments = FreshbooksPayment.where(freshbooks_invoice_id: freshbooks_invoice.freshbooks_id)
      total_paid = payments.sum(:amount) || 0
      invoice_amount = freshbooks_invoice.amount || 0
      [invoice_amount, total_paid]
    end

    def update_invoice_if_changed(new_status, outstanding)
      return if status_and_outstanding_unchanged?(new_status, outstanding)

      freshbooks_invoice.update!(
        status: new_status,
        amount_outstanding: outstanding
      )
    end

    def status_and_outstanding_unchanged?(new_status, outstanding)
      freshbooks_invoice.status == new_status && freshbooks_invoice.amount_outstanding == outstanding
    end

    # Propagate status changes from FreshbooksInvoice to Invoice model
    def propagate_status_to_invoice
      return unless freshbooks_invoice.invoice

      invoice = freshbooks_invoice.invoice
      fb_status = freshbooks_invoice.status

      # Map FreshBooks status to Invoice status
      invoice_status = map_freshbooks_status_to_invoice_status(fb_status)

      # Update invoice if status changed
      return unless invoice.status != invoice_status || invoice.final_status != invoice_status

      invoice.update!(
        status: invoice_status,
        final_status: invoice_status
      )
    end

    # Handle payment received - update invoice status and reconcile
    def handle_payment_received(payment_data)
      return add_error('Payment data required') unless payment_data

      ActiveRecord::Base.transaction do
        # Create or update payment record
        payment = create_or_update_payment(payment_data)

        # Reconcile invoice based on new payment
        reconcile_payments

        # Propagate status to Invoice model
        propagate_status_to_invoice

        payment
      end
    rescue StandardError => e
      add_error("Payment handling failed: #{e.message}")
      Rails.logger.error("InvoiceLifecycleService payment error: #{e.message}\n#{e.backtrace.join("\n")}")
      nil
    end

    # Verify invoice is in sync with FreshBooks
    def verify_sync
      return { synced: false, errors: ['FreshBooks invoice not found'] } unless freshbooks_invoice

      invoices_service = Freshbooks::Invoices.new
      freshbooks_data = invoices_service.get(freshbooks_invoice.freshbooks_id)
      return { synced: false, errors: ['Failed to fetch from FreshBooks'] } unless freshbooks_data

      discrepancies = check_sync_discrepancies(freshbooks_data)

      {
        synced: discrepancies.empty?,
        errors: discrepancies
      }
    rescue StandardError => e
      { synced: false, errors: ["Verification failed: #{e.message}"] }
    end

    def success?
      errors.empty?
    end

    private

    def update_invoice_from_freshbooks_data(invoice_data)
      normalized_status = determine_status_from_invoice_data(invoice_data)
      invoice_attributes = build_invoice_attributes(invoice_data, normalized_status)

      freshbooks_invoice.update!(invoice_attributes)
    end

    def create_or_update_payment(payment_data)
      payment_id = payment_data['id'] || payment_data['paymentid']
      invoice_id = payment_data['invoiceid'] || payment_data.dig('invoice', 'id') || freshbooks_invoice.freshbooks_id

      payment = FreshbooksPayment.find_or_initialize_by(freshbooks_id: payment_id)
      payment.assign_attributes(
        freshbooks_invoice_id: invoice_id,
        amount: extract_amount(payment_data['amount']),
        date: parse_date(payment_data['date']),
        payment_method: payment_data['type'],
        currency_code: payment_data.dig('amount', 'code') || 'USD',
        notes: payment_data['notes'],
        raw_data: payment_data
      )
      payment.save!
      payment
    end

    def determine_status_from_payments(invoice_amount, total_paid, outstanding)
      return 'void' if invoice_voided?

      return 'paid' if fully_paid?(outstanding, invoice_amount)
      return 'sent' if partially_paid?(total_paid, outstanding)

      freshbooks_invoice.status || default_status_for_amount(invoice_amount)
    end

    def map_freshbooks_status_to_invoice_status(fb_status)
      return 'draft' unless fb_status

      status_str = fb_status.to_s
      normalized = status_str.downcase.strip
      normalized = 'voided' if normalized == 'void'

      map_normalized_status(normalized)
    end

    def map_normalized_status(normalized)
      # Invoice model uses same status values as FreshbooksInvoice
      # Both models now use: draft, sent, viewed, paid, voided
      return normalized if %w[paid voided sent viewed draft].include?(normalized)

      normalized || 'draft'
    end

    def normalize_status(status)
      return nil if status.blank?

      InvoiceStatusConverter.to_string_safe(status) || status.to_s
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

    def check_sync_discrepancies(freshbooks_data)
      discrepancies = []
      check_status_discrepancy(freshbooks_data, discrepancies)
      check_amount_discrepancy(freshbooks_data, discrepancies)
      check_outstanding_discrepancy(freshbooks_data, discrepancies)
      discrepancies
    end

    def check_status_discrepancy(freshbooks_data, discrepancies)
      fb_status = normalize_status(freshbooks_data['status'] || freshbooks_data['v3_status'])
      return if freshbooks_invoice.status == fb_status

      discrepancies << "Status mismatch: local=#{freshbooks_invoice.status}, freshbooks=#{fb_status}"
    end

    def check_amount_discrepancy(freshbooks_data, discrepancies)
      fb_amount = extract_amount(freshbooks_data['amount'])
      return if freshbooks_invoice.amount == fb_amount

      discrepancies << "Amount mismatch: local=#{freshbooks_invoice.amount}, freshbooks=#{fb_amount}"
    end

    def check_outstanding_discrepancy(freshbooks_data, discrepancies)
      fb_outstanding = extract_amount(freshbooks_data['outstanding'] || freshbooks_data['amount_outstanding'])
      return if freshbooks_invoice.amount_outstanding == fb_outstanding

      local_outstanding = freshbooks_invoice.amount_outstanding
      discrepancies << "Outstanding mismatch: local=#{local_outstanding}, freshbooks=#{fb_outstanding}"
    end

    def determine_status_from_invoice_data(invoice_data)
      return 'voided' if invoice_data['vis_state'] == 1

      raw_status = invoice_data['status'] || invoice_data['v3_status']
      normalize_status(raw_status)
    end

    def build_invoice_attributes(invoice_data, normalized_status)
      {
        freshbooks_client_id: get_client_id(invoice_data),
        invoice_number: get_invoice_number(invoice_data),
        status: normalized_status,
        amount: extract_amount(invoice_data['amount']),
        amount_outstanding: extract_amount_outstanding(invoice_data),
        date: extract_date(invoice_data),
        due_date: parse_date(invoice_data['due_date']),
        currency_code: extract_currency_code(invoice_data),
        notes: get_notes(invoice_data),
        raw_data: invoice_data
      }
    end

    def get_client_id(invoice_data)
      invoice_data['clientid'] || freshbooks_invoice.freshbooks_client_id
    end

    def get_invoice_number(invoice_data)
      invoice_data['invoice_number'] || freshbooks_invoice.invoice_number
    end

    def extract_amount_outstanding(invoice_data)
      extract_amount(invoice_data['outstanding'] || invoice_data['amount_outstanding'])
    end

    def extract_date(invoice_data)
      parse_date(invoice_data['date'] || invoice_data['create_date'])
    end

    def get_notes(invoice_data)
      invoice_data['notes'] || freshbooks_invoice.notes
    end

    def extract_currency_code(invoice_data)
      invoice_data.dig('amount', 'code') || invoice_data['currency_code'] || freshbooks_invoice.currency_code
    end

    def invoice_voided?
      %w[void voided].include?(freshbooks_invoice.status)
    end

    def fully_paid?(outstanding, invoice_amount)
      outstanding <= 0 && invoice_amount.positive?
    end

    def partially_paid?(total_paid, outstanding)
      total_paid.positive? && outstanding.positive?
    end

    def default_status_for_amount(invoice_amount)
      invoice_amount.positive? ? 'sent' : 'draft'
    end

    # rubocop:disable Naming/PredicateMethod
    # This method returns false for convenience in early returns, but it's not a predicate
    def add_error(message)
      @errors << message
      false
    end
    # rubocop:enable Naming/PredicateMethod
  end
  # rubocop:enable Metrics/ClassLength
end
