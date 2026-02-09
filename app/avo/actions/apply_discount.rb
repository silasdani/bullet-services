# frozen_string_literal: true

module Avo
  module Actions
    class ApplyDiscount < Avo::BaseAction
      self.name = 'Apply 10% Discount'
      self.message = 'Are you sure you want to apply a 10% discount to this invoice?'
      self.confirm_button_label = 'Apply Discount'
      self.cancel_button_label = 'Cancel'
      self.no_confirmation = false

      def handle(query:, _fields:, _current_user:, _resource:, **)
        invoice = query.first
        return error('No invoice selected') unless invoice

        unless RailsAdmin::InvoiceLifecycle.can_apply_discount?(invoice)
          return error('Discount cannot be applied to this invoice in its current status.')
        end

        service = Invoices::ApplyDiscountService.new(invoice: invoice)
        service.call

        if service.success?
          succeed service.result[:message] || '10% discount applied successfully'
        else
          error service.errors.join(', ')
        end
      end

      def visible?(resource:, **)
        return false unless resource.present?

        invoice = resource.record
        invoice.is_a?(Invoice) &&
          invoice.freshbooks_invoices.exists? &&
          RailsAdmin::InvoiceLifecycle.can_apply_discount?(invoice)
      end
    end
  end
end
