# frozen_string_literal: true

module Invoices
  class SendService < ApplicationService
    def initialize(invoice:, email: nil)
      super()
      @invoice = invoice
      @email = email
    end

    def call
      validate_invoice
      email_address = find_email_address
      send_to_freshbooks(email_address)
      sync_status
      @result = { message: "Invoice sent successfully via FreshBooks to #{email_address}" }
    rescue StandardError => e
      log_error(e.message)
      Rails.logger.error("Backtrace: #{e.backtrace.first(10).join('\n')}")
      add_error("Failed to send invoice: #{e.message}")
    end

    private

    attr_reader :invoice, :email

    def validate_invoice
      raise StandardError, 'No FreshBooks invoice found' unless freshbooks_invoice
    end

    def freshbooks_invoice
      @freshbooks_invoice ||= invoice.freshbooks_invoices.first
    end

    def find_email_address
      return email if email.present?

      client_email = find_client_email
      raise StandardError, 'No email address found for client' if client_email.blank?

      client_email
    end

    def find_client_email
      return nil unless invoice.freshbooks_client_id.present?

      client = FreshbooksClient.find_by(freshbooks_id: invoice.freshbooks_client_id)
      client&.email
    end

    # rubocop:disable Metrics/AbcSize
    def send_to_freshbooks(email_address)
      invoices_client = Freshbooks::Invoices.new
      # Include lines so we preserve them when updating (API requires all lines in PUT)
      current_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id, includes: ['lines'])

      raise StandardError, 'Could not retrieve invoice from FreshBooks' unless current_invoice

      enable_online_payments(freshbooks_invoice.freshbooks_id)

      lines = build_lines(current_invoice)

      updated_invoice = invoices_client.update(
        freshbooks_invoice.freshbooks_id,
        client_id: current_invoice['customerid'] || invoice.freshbooks_client_id,
        date: current_invoice['create_date'] || invoice.created_at&.to_date&.to_s,
        due_date: current_invoice['due_date'],
        currency: current_invoice['currency_code'] || 'GBP',
        notes: current_invoice['notes'],
        lines: lines,
        action_email: true,
        email_recipients: [email_address],
        email_include_pdf: true
      )

      # Use update response to sync status immediately (FreshBooks marks as sent when email is sent)
      sync_status_from_response(updated_invoice) if updated_invoice.present?
    end
    # rubocop:enable Metrics/AbcSize

    def build_lines(current_invoice)
      (current_invoice['lines'] || []).map do |line|
        {
          name: line['name'],
          description: line['description'],
          quantity: line['qty'] || 1,
          cost: line.dig('unit_cost', 'amount') || line['unit_cost'],
          currency: line.dig('unit_cost', 'code') || 'GBP',
          type: line['type'] || 0
        }
      end
    end

    def sync_status_from_response(freshbooks_data)
      return unless freshbooks_invoice

      normalized_status = determine_status(freshbooks_data)
      return if normalized_status.blank?

      freshbooks_invoice.update!(status: normalized_status)
      invoice.update!(status: normalized_status, final_status: normalized_status)
    end

    def determine_status(invoice_data)
      return 'voided' if invoice_data['vis_state'] == 1

      raw_status = invoice_data['status'] || invoice_data['v3_status']
      return nil if raw_status.blank?

      # Handle numeric status (1=draft, 2=sent, 3=viewed, 4=paid, 5=void)
      return Freshbooks::InvoiceStatusConverter.to_string_safe(raw_status) if raw_status.is_a?(Integer)
      return raw_status.to_s.downcase if %w[draft sent viewed paid void voided].include?(raw_status.to_s.downcase)

      Freshbooks::InvoiceStatusConverter.to_string_safe(raw_status) || raw_status.to_s.downcase
    end

    def sync_status
      return unless freshbooks_invoice&.freshbooks_id.present?

      begin
        freshbooks_invoice.sync_from_freshbooks
        invoice.sync_status_from_freshbooks_invoice
      rescue StandardError => e
        Rails.logger.warn("Failed to sync from FreshBooks after sending: #{e.message}")
        invoice.update!(status: 'sent', final_status: 'sent')
        freshbooks_invoice.update!(status: 'sent')
      end
    end

    def log_error(message)
      Rails.logger.error("Failed to send invoice: #{message}")
    end

    # Enable online payments so FreshBooks email shows "Pay Invoice" instead of "View Invoice"
    # Uses account's configured gateway if available, otherwise tries stripe → paypal → fbpay
    def enable_online_payments(invoice_id)
      payment_options = Freshbooks::PaymentOptions.new
      gateways = [payment_options.list&.dig('gateway_name')].compact
      gateways = %w[stripe paypal fbpay] if gateways.empty?

      gateways.find do |gateway|
        payment_options.enable_for_invoice(invoice_id, gateway_name: gateway, has_credit_card: true)
        true
      rescue FreshbooksError, StandardError => e
        Rails.logger.debug("Payment gateway #{gateway} not available: #{e.message}")
        false
      end
    end
  end
end
