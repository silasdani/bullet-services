# frozen_string_literal: true

module Avo
  module Actions
    class ApplyDiscount < Avo::BaseAction
      self.name = 'Apply 10% Discount'
      self.message = 'Are you sure you want to apply a 10% discount to this invoice?'
      self.confirm_button_label = 'Apply Discount'
      self.cancel_button_label = 'Cancel'

      def handle(query:, **)
        invoice = extract_invoice(query)
        return error('No invoice selected') unless invoice
        unless RailsAdmin::InvoiceLifecycle.can_apply_discount?(invoice)
          return error('Discount cannot be applied to this invoice in its current status.')
        end

        service = Invoices::ApplyDiscountService.new(invoice: invoice)
        service.call

        service.success? ? succeed(service.result[:message]) : error(service.errors.join(', '))
      rescue StandardError => e
        Rails.logger.error("ApplyDiscount: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        error("Failed to apply discount: #{e.message}")
      end

      def visible?(resource:, **)
        invoice = resource&.record
        invoice.is_a?(Invoice) && invoice.freshbooks_invoices.exists? && RailsAdmin::InvoiceLifecycle.can_apply_discount?(invoice)
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
