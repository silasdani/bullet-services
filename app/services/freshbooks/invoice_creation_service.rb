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

      freshbooks_invoice_id = freshbooks_invoice_data['id'] || freshbooks_invoice_data['invoiceid']
      invoice_url = extract_invoice_url(freshbooks_invoice_data)

      pdf_data = PdfFetcher.new(invoices_client, freshbooks_invoice_id, freshbooks_invoice_data).call

      update_invoice_and_sync_record(freshbooks_invoice_data, invoice_url, freshbooks_invoice_id)

      @result = {
        freshbooks_invoice: freshbooks_invoice_data,
        invoice: invoice,
        pdf_url: pdf_data[:download_url],
        pdf_base64: pdf_data[:base64],
        invoice_url: invoice_url
      }
    end

    def update_invoice_and_sync_record(freshbooks_invoice_data, invoice_url, invoice_id)
      invoice.update!(
        freshbooks_client_id: client_id,
        invoice_pdf_link: invoice_url
      )

      InvoiceRecordSyncer.new(freshbooks_invoice_data, invoice, client_id, invoice_url).call
      log_info("Created FreshBooks invoice #{invoice_id} for invoice #{invoice.id}")
    end

    def build_invoice_params
      {
        client_id: client_id,
        date: invoice.created_at&.to_date || Date.current,
        currency: 'USD',
        notes: build_notes,
        tax_included: 'yes', # VAT is already included in the price
        tax_calculation: 'item',
        lines: build_invoice_lines
      }
    end

    def build_invoice_lines
      return lines if lines.any?

      [build_default_invoice_line]
    end

    def build_default_invoice_line
      {
        name: invoice.name || 'Invoice',
        description: build_line_description,
        quantity: 1,
        cost: determine_line_cost,
        type: 0, # Service
        tax_included: invoice.included_vat_amount.present?
      }
    end

    def build_line_description
      invoice.job || invoice.wrs_link || ''
    end

    def determine_line_cost
      invoice.included_vat_amount || invoice.excluded_vat_amount || 0
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

    def extract_invoice_url(freshbooks_data)
      business_id = FreshbooksToken.current&.business_id || ENV.fetch('FRESHBOOKS_BUSINESS_ID', nil)
      invoice_id = freshbooks_data['id'] || freshbooks_data['invoiceid']
      return nil unless business_id && invoice_id

      "https://my.freshbooks.com/#/invoice/#{business_id}-#{invoice_id}"
    end

    def send_invoice_email
      invoices_client = Freshbooks::Invoices.new
      freshbooks_invoice_id = @result[:freshbooks_invoice]['id'] || @result[:freshbooks_invoice]['invoiceid']

      invoices_client.send_by_email(
        freshbooks_invoice_id,
        email: email_to,
        subject: "Invoice #{invoice.name || invoice.slug}",
        message: 'Please find your invoice attached. You can pay online using your FreshBooks client portal.'
      )

      log_info("Sent invoice email to #{email_to} for FreshBooks invoice #{freshbooks_invoice_id}")
    end
  end
end
