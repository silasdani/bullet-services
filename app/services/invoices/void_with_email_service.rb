# frozen_string_literal: true

module Invoices
  class VoidWithEmailService < ApplicationService
    def initialize(invoice:)
      super()
      @invoice = invoice
    end

    def call
      validate_invoice
      client_email = find_client_email
      void_in_freshbooks
      send_voidance_email(client_email)
      update_status
      @result = { message: 'Invoice voided and voidance email sent successfully' }
    rescue StandardError => e
      log_error(e.message)
      Rails.logger.error("Backtrace: #{e.backtrace.first(5).join('\n')}")
      add_error("Failed to void invoice and send email: #{e.message}")
    end

    private

    attr_reader :invoice

    def validate_invoice
      raise StandardError, 'No FreshBooks invoice found' unless freshbooks_invoice
    end

    def freshbooks_invoice
      @freshbooks_invoice ||= invoice.freshbooks_invoices.first
    end

    def find_client_email
      return nil unless invoice.freshbooks_client_id.present?

      client = FreshbooksClient.find_by(freshbooks_id: invoice.freshbooks_client_id)
      client_email = client&.email

      raise StandardError, 'No email address found for client' if client_email.blank?

      client_email
    end

    def void_in_freshbooks
      return unless freshbooks_invoice&.freshbooks_id.present?

      invoices_client = Freshbooks::Invoices.new
      invoices_client.void(freshbooks_invoice.freshbooks_id)

      sleep(0.5)
      freshbooks_invoice.sync_from_freshbooks
      freshbooks_invoice.reload
    end

    def send_voidance_email(client_email)
      InvoiceMailer.with(
        invoice: invoice,
        client_email: client_email
      ).voided_invoice_email.deliver_now
    end

    def update_status
      invoice.reload
      invoice.update_columns(
        status: 'voided + email sent',
        final_status: 'voided + email sent',
        updated_at: Time.current
      )
    end

    def log_error(message)
      Rails.logger.error("Failed to void invoice with email: #{message}")
    end
  end
end
