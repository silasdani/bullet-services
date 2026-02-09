# frozen_string_literal: true

module Avo
  module Actions
    class MarkPaid < Avo::BaseAction
      self.name = 'Mark as Paid'
      self.message = 'Are you sure you want to mark this invoice as paid?'
      self.confirm_button_label = 'Mark as Paid'
      self.cancel_button_label = 'Cancel'
      self.no_confirmation = false

      def handle(query:, _fields:, _current_user:, _resource:, **)
        invoice = query.first
        return error('No invoice selected') unless invoice

        unless RailsAdmin::InvoiceLifecycle.can_mark_paid?(invoice)
          return error('Invoice cannot be marked as paid in its current status.')
        end

        service = Invoices::MarkPaidService.new(invoice: invoice)
        service.call

        if service.success?
          succeed service.result[:message] || 'Invoice marked as paid'
        else
          error service.errors.join(', ')
        end
      end

      def visible?(resource:, **)
        return false unless resource.present?

        invoice = resource.record
        invoice.is_a?(Invoice) &&
          invoice.freshbooks_invoices.exists? &&
          RailsAdmin::InvoiceLifecycle.can_mark_paid?(invoice)
      end
    end
  end
end
