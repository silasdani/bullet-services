# frozen_string_literal: true

module Freshbooks
  # Central service for managing FreshBooks invoice lifecycle and ensuring data consistency
  # This service ensures that invoice status, payments, and related records stay in sync
  class InvoiceLifecycleService
    attr_reader :freshbooks_invoice, :errors

    def initialize(freshbooks_invoice)
      @freshbooks_invoice = freshbooks_invoice
      @errors = []
    end

    # Sync invoice from FreshBooks API and reconcile all related data
    def sync_from_freshbooks
      return add_error('FreshBooks invoice not found') unless freshbooks_invoice

      invoices_service = Freshbooks::Invoices.new
      invoice_data = invoices_service.get(freshbooks_invoice.freshbooks_id)
      return add_error('Failed to fetch invoice from FreshBooks') unless invoice_data

      ActiveRecord::Base.transaction do
        update_invoice_from_freshbooks_data(invoice_data)
        reconcile_payments
        propagate_status_to_invoice
      end

      true
    rescue StandardError => e
      add_error("Sync failed: #{e.message}")
      Rails.logger.error("InvoiceLifecycleService sync error: #{e.message}\n#{e.backtrace.join("\n")}")
      false
    end

    # Reconcile invoice status based on payments
    def reconcile_payments
      return unless freshbooks_invoice

      payments = FreshbooksPayment.where(freshbooks_invoice_id: freshbooks_invoice.freshbooks_id)
      total_paid = payments.sum(:amount) || 0
      invoice_amount = freshbooks_invoice.amount || 0

      # Calculate outstanding amount
      outstanding = invoice_amount - total_paid

      # Determine status based on payments
      new_status = determine_status_from_payments(invoice_amount, total_paid, outstanding)

      # Update if status or outstanding amount changed
      return unless freshbooks_invoice.status != new_status || freshbooks_invoice.amount_outstanding != outstanding

      freshbooks_invoice.update!(
        status: new_status,
        amount_outstanding: outstanding
      )
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

      discrepancies = []

      # Check status
      fb_status = normalize_status(freshbooks_data['status'] || freshbooks_data['v3_status'])
      if freshbooks_invoice.status != fb_status
        discrepancies << "Status mismatch: local=#{freshbooks_invoice.status}, freshbooks=#{fb_status}"
      end

      # Check amounts
      fb_amount = extract_amount(freshbooks_data['amount'])
      if freshbooks_invoice.amount != fb_amount
        discrepancies << "Amount mismatch: local=#{freshbooks_invoice.amount}, freshbooks=#{fb_amount}"
      end

      fb_outstanding = extract_amount(freshbooks_data['outstanding'] || freshbooks_data['amount_outstanding'])
      if freshbooks_invoice.amount_outstanding != fb_outstanding
        discrepancies << "Outstanding mismatch: local=#{freshbooks_invoice.amount_outstanding}, freshbooks=#{fb_outstanding}"
      end

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
      # Check vis_state first - if it's 1, invoice is voided/deleted
      vis_state = invoice_data['vis_state']
      normalized_status = if vis_state == 1
                            'voided'
                          else
                            raw_status = invoice_data['status'] || invoice_data['v3_status']
                            normalize_status(raw_status)
                          end

      freshbooks_invoice.update!(
        freshbooks_client_id: invoice_data['clientid'] || freshbooks_invoice.freshbooks_client_id,
        invoice_number: invoice_data['invoice_number'] || freshbooks_invoice.invoice_number,
        status: normalized_status,
        amount: extract_amount(invoice_data['amount']),
        amount_outstanding: extract_amount(invoice_data['outstanding'] || invoice_data['amount_outstanding']),
        date: parse_date(invoice_data['date'] || invoice_data['create_date']),
        due_date: parse_date(invoice_data['due_date']),
        currency_code: invoice_data.dig('amount',
                                        'code') || invoice_data['currency_code'] || freshbooks_invoice.currency_code,
        notes: invoice_data['notes'] || freshbooks_invoice.notes,
        raw_data: invoice_data
      )
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
      return 'void' if %w[void voided].include?(freshbooks_invoice.status)

      if outstanding <= 0 && invoice_amount.positive?
        'paid'
      elsif total_paid.positive? && outstanding.positive?
        'sent' # Partially paid
      elsif total_paid.zero? && invoice_amount.positive?
        freshbooks_invoice.status || 'sent'
      else
        freshbooks_invoice.status || 'draft'
      end
    end

    def map_freshbooks_status_to_invoice_status(fb_status)
      # Normalize the status first
      normalized = fb_status&.to_s&.downcase&.strip
      normalized = 'voided' if normalized == 'void'

      # Invoice model uses same status values as FreshbooksInvoice
      # Both models now use: draft, sent, viewed, paid, voided
      case normalized
      when 'paid'
        'paid'
      when 'voided'
        'voided'
      when 'sent', 'viewed'
        normalized # Keep sent/viewed as-is since Invoice supports both
      when 'draft'
        'draft'
      else
        normalized || 'draft'
      end
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

    def add_error(message)
      @errors << message
      false
    end
  end
end
