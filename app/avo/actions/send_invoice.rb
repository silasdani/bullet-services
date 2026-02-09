# frozen_string_literal: true

module Avo
  module Actions
    class SendInvoice < Avo::BaseAction
      self.name = 'Send Invoice'
      self.message = 'Are you sure you want to send this invoice?'
      self.confirm_button_label = 'Send'
      self.cancel_button_label = 'Cancel'
      self.no_confirmation = false

      def fields
        field :email, as: :text, placeholder: 'Leave empty to use client email',
                      help: 'Optional: Override the client email address'
      end

      def handle(query:, fields:, _current_user:, _resource:, **)
        invoice = query.first
        return error('No invoice selected') unless invoice

        unless RailsAdmin::InvoiceLifecycle.can_send?(invoice)
          return error('Invoice cannot be sent. It must be in draft status.')
        end

        service = Invoices::SendService.new(invoice: invoice, email: fields[:email])
        service.call

        if service.success?
          succeed service.result[:message] || 'Invoice sent successfully'
        else
          error service.errors.join(', ')
        end
      end

      def visible?(resource:, **)
        return false unless resource.present?

        invoice = resource.record
        invoice.is_a?(Invoice) &&
          invoice.freshbooks_invoices.exists? &&
          RailsAdmin::InvoiceLifecycle.can_send?(invoice)
      end
    end
  end
end
