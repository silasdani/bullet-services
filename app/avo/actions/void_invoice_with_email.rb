# frozen_string_literal: true

module Avo
  module Actions
    class VoidInvoiceWithEmail < Avo::BaseAction
      self.name = 'Void Invoice & Send Email'
      self.message = 'Are you sure you want to void this invoice and send a voidance email to the client?'
      self.confirm_button_label = 'Void & Send Email'
      self.cancel_button_label = 'Cancel'

      def handle(query:, **)
        invoice = extract_invoice(query)
        return error('No invoice selected') unless invoice
        unless RailsAdmin::InvoiceLifecycle.can_void?(invoice)
          return error('Invoice cannot be voided in its current status.')
        end

        service = Invoices::VoidWithEmailService.new(invoice: invoice)
        service.call

        service.success? ? succeed(service.result[:message]) : error(service.errors.join(', '))
      rescue StandardError => e
        Rails.logger.error("VoidInvoiceWithEmail: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        error("Failed to void invoice and send email: #{e.message}")
      end

      def visible?(resource:, **)
        invoice = resource&.record
        invoice.is_a?(Invoice) && invoice.freshbooks_invoices.exists? && RailsAdmin::InvoiceLifecycle.can_void?(invoice)
      end

      private

      def extract_invoice(query)
        record = query&.first
        return nil unless record

        record.respond_to?(:record) ? record.record : record
      end
    end
  end
end
