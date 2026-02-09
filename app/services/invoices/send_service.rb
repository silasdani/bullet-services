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
      current_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)

      raise StandardError, 'Could not retrieve invoice from FreshBooks' unless current_invoice

      lines = build_lines(current_invoice)

      invoices_client.update(
        freshbooks_invoice.freshbooks_id,
        client_id: current_invoice['customerid'] || invoice.freshbooks_client_id,
        date: current_invoice['create_date'] || invoice.created_at&.to_date&.to_s,
        due_date: current_invoice['due_date'],
        currency: current_invoice['currency_code'] || 'USD',
        notes: current_invoice['notes'],
        lines: lines,
        action_email: true,
        email_recipients: [email_address]
      )
    end
    # rubocop:enable Metrics/AbcSize

    def build_lines(current_invoice)
      (current_invoice['lines'] || []).map do |line|
        {
          name: line['name'],
          description: line['description'],
          quantity: line['qty'] || 1,
          cost: line.dig('unit_cost', 'amount') || line['unit_cost'],
          currency: line.dig('unit_cost', 'code') || 'USD',
          type: line['type'] || 0
        }
      end
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
  end
end
