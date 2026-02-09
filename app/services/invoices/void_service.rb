# frozen_string_literal: true

module Invoices
  class VoidService < ApplicationService
    def initialize(invoice:)
      super()
      @invoice = invoice
    end

    def call
      validate_invoice
      check_draft_status
      void_in_freshbooks
      sync_status
      @result = { message: 'Invoice voided successfully' }
    rescue StandardError => e
      log_error(e.message)
      Rails.logger.error("Backtrace: #{e.backtrace.first(5).join('\n')}")
      add_error("Failed to void invoice: #{e.message}")
    end

    private

    attr_reader :invoice

    def validate_invoice
      raise StandardError, 'No FreshBooks invoice found' unless freshbooks_invoice
    end

    def freshbooks_invoice
      @freshbooks_invoice ||= invoice.freshbooks_invoices.first
    end

    def check_draft_status
      return unless freshbooks_invoice&.freshbooks_id.present?

      invoices_client = Freshbooks::Invoices.new
      current_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)

      return unless current_invoice

      return unless current_invoice['status'] == 1

      raise StandardError, 'Cannot void a draft invoice. Please send the invoice first before voiding.'
    end

    def void_in_freshbooks
      return unless freshbooks_invoice&.freshbooks_id.present?

      invoices_client = Freshbooks::Invoices.new

      begin
        invoices_client.void(freshbooks_invoice.freshbooks_id)
      rescue FreshbooksError => e
        error_msg = parse_freshbooks_error(e)
        raise StandardError, error_msg
      end
    end

    def sync_status
      return unless freshbooks_invoice&.freshbooks_id.present?

      sleep(0.5)
      freshbooks_invoice.sync_from_freshbooks
      freshbooks_invoice.reload

      invoice.update!(status: 'voided', final_status: 'voided')

      status_message = if %w[voided void].include?(freshbooks_invoice.status)
                         'Invoice voided successfully'
                       else
                         'Invoice voided successfully (status may update on next sync)'
                       end

      @result = { message: status_message }
    end

    def parse_freshbooks_error(error)
      error_msg = "Failed to void FreshBooks invoice: #{error.message}"
      return error_msg unless error.respond_to?(:response_body) && error.response_body.present?

      begin
        error_data = JSON.parse(error.response_body)
        if error_data.dig('response', 'errors')
          detailed_errors = error_data.dig('response', 'errors').map { |err| err['message'] }.join(', ')
          error_msg += " - #{detailed_errors}"
        end
      rescue JSON::ParserError
        # Ignore JSON parse errors
      end
      error_msg
    end

    def log_error(message)
      Rails.logger.error("Failed to void invoice: #{message}")
    end
  end
end
