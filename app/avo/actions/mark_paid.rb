# frozen_string_literal: true

module Avo
  module Actions
    class MarkPaid < Avo::BaseAction
      self.name = 'Mark as Paid'
      self.message = 'Are you sure you want to mark this invoice as paid?'
      self.confirm_button_label = 'Mark as Paid'
      self.cancel_button_label = 'Cancel'

      def handle(query:, **)
        invoice = extract_invoice(query)
        return error('No invoice selected') unless invoice
        unless RailsAdmin::InvoiceLifecycle.can_mark_paid?(invoice)
          return error('Invoice cannot be marked as paid in its current status.')
        end

        service = Invoices::MarkPaidService.new(invoice: invoice)
        service.call

        service.success? ? succeed(service.result[:message]) : error(service.errors.join(', '))
      rescue StandardError => e
        Rails.logger.error("MarkPaid: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        error("Failed to mark invoice as paid: #{e.message}")
      end

      def visible?(resource:, **)
        invoice = resource&.record
        invoice.is_a?(Invoice) && invoice.freshbooks_invoices.exists? && RailsAdmin::InvoiceLifecycle.can_mark_paid?(invoice)
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
