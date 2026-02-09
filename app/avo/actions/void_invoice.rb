# frozen_string_literal: true

module Avo
  module Actions
    class VoidInvoice < Avo::BaseAction
      self.name = 'Void Invoice'
      self.message = 'Are you sure you want to void this invoice? This action cannot be undone.'
      self.confirm_button_label = 'Void'
      self.cancel_button_label = 'Cancel'
      self.no_confirmation = false

      def handle(query:, _fields:, _current_user:, _resource:, **)
        invoice = query.first
        return error('No invoice selected') unless invoice

        unless RailsAdmin::InvoiceLifecycle.can_void?(invoice)
          return error('Invoice cannot be voided in its current status.')
        end

        service = Invoices::VoidService.new(invoice: invoice)
        service.call

        if service.success?
          succeed service.result[:message] || 'Invoice voided successfully'
        else
          error service.errors.join(', ')
        end
      end

      def visible?(resource:, **)
        return false unless resource.present?

        invoice = resource.record
        invoice.is_a?(Invoice) &&
          invoice.freshbooks_invoices.exists? &&
          RailsAdmin::InvoiceLifecycle.can_void?(invoice)
      end
    end
  end
end
