# frozen_string_literal: true

module Avo
  module Actions
    class SendInvoice < Avo::BaseAction
      self.name = 'Send Invoice'
      self.message = 'Are you sure you want to send this invoice?'
      self.confirm_button_label = 'Send'
      self.cancel_button_label = 'Cancel'

      def fields
        field :email, as: :text, placeholder: 'Leave empty to use client email',
                      help: 'Optional: Override the client email address'
      end

      def handle(query:, fields: {}, **)
        invoice = extract_invoice(query)
        return error('No invoice selected') unless invoice
        unless RailsAdmin::InvoiceLifecycle.can_send?(invoice)
          return error('Invoice cannot be sent. It must be in draft status.')
        end

        service = Invoices::SendService.new(invoice: invoice, email: (fields[:email] || fields['email']).presence)
        service.call

        service.success? ? succeed(service.result[:message]) : error(service.errors.join(', '))
      rescue StandardError => e
        Rails.logger.error("SendInvoice: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        error("Failed to send invoice: #{e.message}")
      end

      def visible?(resource:, **)
        invoice = resource&.record
        invoice.is_a?(Invoice) && invoice.freshbooks_invoices.exists? && RailsAdmin::InvoiceLifecycle.can_send?(invoice)
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
