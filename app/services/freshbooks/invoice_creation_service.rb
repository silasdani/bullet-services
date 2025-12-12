# frozen_string_literal: true

module Freshbooks
  class InvoiceCreationService < ApplicationService
    attribute :invoice
    attribute :client_id, :string
    attribute :lines, default: -> { [] }
    attribute :send_email, :boolean, default: -> { false }
    attribute :email_to, :string

    def call
      return add_error('Invoice is required') if invoice.nil?
      return add_error('Client ID is required') if client_id.blank?

      with_error_handling do
        create_freshbooks_invoice
        send_invoice_email if send_email && email_to.present?
      end
    end

    private

    def create_freshbooks_invoice
      invoices_client = Freshbooks::Invoices.new

      invoice_params = build_invoice_params
      freshbooks_invoice_data = invoices_client.create(invoice_params)

      # Get payment link and PDF URL
      freshbooks_invoice_id = freshbooks_invoice_data['id'] || freshbooks_invoice_data['invoiceid']
      payment_link = invoices_client.get_payment_link(freshbooks_invoice_id)
      pdf_url = extract_pdf_url(freshbooks_invoice_data)

      # Store the FreshBooks invoice ID and payment link
      invoice.update!(
        freshbooks_client_id: client_id,
        invoice_pdf_link: pdf_url
      )

      # Create or update local FreshbooksInvoice record
      sync_freshbooks_invoice_record(freshbooks_invoice_data, payment_link)

      log_info("Created FreshBooks invoice #{freshbooks_invoice_id} for invoice #{invoice.id}")
      @result = {
        freshbooks_invoice: freshbooks_invoice_data,
        invoice: invoice,
        payment_link: payment_link,
        pdf_url: pdf_url
      }
    end

    def build_invoice_params
      {
        client_id: client_id,
        date: invoice.created_at&.to_date || Date.current,
        due_date: calculate_due_date,
        currency: 'USD',
        notes: build_notes,
        lines: build_invoice_lines
      }
    end

    def build_invoice_lines
      return lines if lines.any?

      # Default line item from invoice amounts
      [
        {
          name: invoice.name || 'Invoice',
          description: invoice.job || invoice.wrs_link || '',
          quantity: 1,
          cost: invoice.included_vat_amount || invoice.excluded_vat_amount || 0,
          type: 0 # Service
        }
      ]
    end

    def build_notes
      notes = []
      notes << "Job: #{invoice.job}" if invoice.job.present?
      notes << "WRS Link: #{invoice.wrs_link}" if invoice.wrs_link.present?
      notes.join("\n")
    end

    def calculate_due_date
      # Default to 30 days from invoice date
      (invoice.created_at&.to_date || Date.current) + 30.days
    end

    def extract_pdf_url(freshbooks_data)
      # FreshBooks PDF URL format
      business_id = FreshbooksToken.current&.business_id || ENV.fetch('FRESHBOOKS_BUSINESS_ID', nil)
      invoice_id = freshbooks_data['id'] || freshbooks_data['invoiceid']
      return nil unless business_id && invoice_id

      "https://my.freshbooks.com/#/invoices/#{business_id}/#{invoice_id}/pdf"
    end

    def sync_freshbooks_invoice_record(freshbooks_data, _payment_link = nil)
      fb_invoice = find_or_initialize_fb_invoice(freshbooks_data)
      assign_fb_invoice_attributes(fb_invoice, freshbooks_data)
      fb_invoice.save!
    end

    def find_or_initialize_fb_invoice(freshbooks_data)
      invoice_id = freshbooks_data['id'] || freshbooks_data['invoiceid']
      FreshbooksInvoice.find_or_initialize_by(freshbooks_id: invoice_id)
    end

    def assign_fb_invoice_attributes(fb_invoice, freshbooks_data)
      fb_invoice.assign_attributes(
        **build_fb_invoice_basic_attributes(freshbooks_data),
        **build_fb_invoice_financial_attributes(freshbooks_data),
        **build_fb_invoice_metadata(freshbooks_data)
      )
    end

    def build_fb_invoice_basic_attributes(freshbooks_data)
      {
        freshbooks_client_id: client_id,
        invoice_number: freshbooks_data['invoice_number'],
        status: freshbooks_data['status'] || freshbooks_data['v3_status'],
        notes: freshbooks_data['notes'],
        invoice_id: invoice.id
      }
    end

    def build_fb_invoice_financial_attributes(freshbooks_data)
      {
        amount: extract_amount(freshbooks_data['amount']),
        amount_outstanding: extract_amount(freshbooks_data['outstanding'] || freshbooks_data['amount_outstanding']),
        currency_code: freshbooks_data.dig('amount', 'code') || freshbooks_data['currency_code']
      }
    end

    def build_fb_invoice_metadata(freshbooks_data)
      {
        date: parse_date(freshbooks_data['create_date'] || freshbooks_data['date']),
        due_date: parse_date(freshbooks_data['due_date']),
        pdf_url: extract_pdf_url(freshbooks_data),
        raw_data: freshbooks_data
      }
    end

    def extract_amount(amount_data)
      return nil unless amount_data

      amount_data.is_a?(Hash) ? amount_data['amount'].to_d : amount_data.to_d
    end

    def parse_date(date_string)
      return nil unless date_string

      Date.parse(date_string)
    rescue ArgumentError
      nil
    end

    def send_invoice_email
      invoices_client = Freshbooks::Invoices.new
      freshbooks_invoice_id = @result[:freshbooks_invoice]['id'] || @result[:freshbooks_invoice]['invoiceid']

      invoices_client.send_by_email(
        freshbooks_invoice_id,
        email: email_to,
        subject: "Invoice #{invoice.name || invoice.slug}",
        message: "Please find your invoice attached. You can pay online using this link: #{@result[:payment_link]}"
      )

      log_info("Sent invoice email to #{email_to} for FreshBooks invoice #{freshbooks_invoice_id}")
    end
  end
end
