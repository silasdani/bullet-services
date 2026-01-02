# frozen_string_literal: true

module Invoices
  class ActionService < ApplicationService
    attribute :invoice
    attribute :action, :string
    attribute :discount_amount
    attribute :notify_client

    def call
      return add_error('Invoice is required') if invoice.nil?
      return add_error('Action is required') if action.blank?

      case action.to_s
      when 'send'
        handle_send
      when 'void'
        handle_void(notify_client: false)
      when 'void_and_notify'
        handle_void(notify_client: true)
      when 'discount'
        handle_discount
      else
        add_error('Unsupported action')
      end
    end

    private

    def handle_send
      with_error_handling do
        fb_invoice = freshbooks_invoice_record
        return add_error('FreshBooks invoice not found') unless fb_invoice

        client_email = invoice.flat_address # fallback, ideally from client details

        invoices_client.send_by_email(
          fb_invoice.freshbooks_id,
          email: client_email,
          subject: "Invoice #{fb_invoice.invoice_number || invoice.name}",
          message: 'Please find your invoice attached.'
        )

        invoice.update!(status: 'sent')
        @result = { action: 'send' }
      end
    end

    def handle_void(notify_client:)
      with_error_handling do
        fb_invoice = freshbooks_invoice_record
        return add_error('FreshBooks invoice not found') unless fb_invoice

        # Note: FreshBooks API doesn't allow setting status to 'void' via update endpoint
        # Status can only be set to: 'draft', 'sent', 'viewed', or 'disputed'
        # We only update local records. The invoice status in FreshBooks will remain as-is
        # or can be voided manually through FreshBooks UI if needed

        fb_invoice.update!(status: 'void')
        invoice.update!(final_status: 'void')

        send_void_confirmation_email!(fb_invoice) if notify_client

        @result = { action: 'void', notify_client: notify_client }
      end
    end

    def handle_discount
      with_error_handling do
        fb_invoice = freshbooks_invoice_record
        return add_error('FreshBooks invoice not found') unless fb_invoice

        amount = BigDecimal(discount_amount.to_s)
        apply_discount_to_freshbooks(fb_invoice, amount)
        update_fb_invoice_amounts(fb_invoice, amount)

        @result = { action: 'discount', discount_amount: amount.to_s }
      end
    end

    def apply_discount_to_freshbooks(fb_invoice, amount)
      invoices_client.update(
        fb_invoice.freshbooks_id,
        lines: build_discount_line(amount)
      )
    end

    def build_discount_line(amount)
      [
        {
          name: 'Discount',
          description: 'Applied discount via automation',
          quantity: 1,
          cost: -amount,
          type: 0
        }
      ]
    end

    def update_fb_invoice_amounts(fb_invoice, amount)
      fb_invoice.update!(
        amount: fb_invoice.amount - amount,
        amount_outstanding: fb_invoice.amount_outstanding - amount
      )
    end

    def freshbooks_invoice_record
      invoice.freshbooks_invoices.order(created_at: :desc).first
    end

    def invoices_client
      @invoices_client ||= Freshbooks::Invoices.new
    end

    def send_void_confirmation_email!(_fb_invoice)
      client_email = invoice.flat_address
      return if client_email.blank? || !client_email.match?(/\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i)

      InvoiceMailer.with(
        invoice: invoice,
        client_email: client_email
      ).voided_invoice_email.deliver_now
    end
  end
end
