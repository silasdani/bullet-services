# frozen_string_literal: true

module Invoices
  class MarkPaidService < ApplicationService
    def initialize(invoice:)
      super()
      @invoice = invoice
    end

    def call
      validate_invoice
      update_local_status
      update_freshbooks_status
      @result = { message: 'Invoice marked as paid' }
    rescue StandardError => e
      log_error(e.message)
      Rails.logger.error("Backtrace: #{e.backtrace.first(5).join('\n')}")
      add_error("Failed to mark invoice as paid: #{e.message}")
    end

    private

    attr_reader :invoice

    def validate_invoice
      raise StandardError, 'No FreshBooks invoice found' unless freshbooks_invoice
    end

    def freshbooks_invoice
      @freshbooks_invoice ||= invoice.freshbooks_invoices.first
    end

    def update_local_status
      freshbooks_invoice.update!(status: 'paid')
      invoice.update!(status: 'paid', final_status: 'paid')
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def update_freshbooks_status
      return unless freshbooks_invoice&.freshbooks_id.present?

      invoices_client = Freshbooks::Invoices.new
      current_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)

      return unless current_invoice

      lines = build_lines(current_invoice)

      invoices_client.update(
        freshbooks_invoice.freshbooks_id,
        client_id: current_invoice['customerid'] || invoice.freshbooks_client_id,
        date: current_invoice['create_date'] || invoice.created_at&.to_date&.to_s,
        due_date: current_invoice['due_date'],
        currency: current_invoice['currency_code'] || 'USD',
        notes: current_invoice['notes'],
        lines: lines,
        status: 'paid'
      )
    rescue StandardError => e
      Rails.logger.warn("Failed to update FreshBooks invoice: #{e.message}")
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

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

    def log_error(message)
      Rails.logger.error("Failed to mark invoice as paid: #{message}")
    end
  end
end
