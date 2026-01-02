# frozen_string_literal: true

module Freshbooks
  # Service for syncing FreshBooks invoice data to local FreshbooksInvoice records
  class InvoiceRecordSyncer
    def initialize(freshbooks_data, invoice, client_id, invoice_url = nil)
      @freshbooks_data = freshbooks_data
      @invoice = invoice
      @client_id = client_id
      @invoice_url = invoice_url
    end

    def call
      fb_invoice = find_or_initialize_fb_invoice
      assign_fb_invoice_attributes(fb_invoice)
      fb_invoice.save!
    end

    private

    attr_reader :freshbooks_data, :invoice, :client_id, :invoice_url

    def find_or_initialize_fb_invoice
      invoice_id = freshbooks_data['id'] || freshbooks_data['invoiceid']
      FreshbooksInvoice.find_or_initialize_by(freshbooks_id: invoice_id)
    end

    def assign_fb_invoice_attributes(fb_invoice)
      fb_invoice.assign_attributes(
        **build_basic_attributes,
        **build_financial_attributes,
        **build_metadata
      )
    end

    def build_basic_attributes
      # Check vis_state first - if it's 1, invoice is voided/deleted
      vis_state = freshbooks_data['vis_state']
      normalized_status = if vis_state == 1
                            'voided'
                          else
                            raw_status = freshbooks_data['status'] || freshbooks_data['v3_status']
                            normalize_status(raw_status)
                          end

      {
        freshbooks_client_id: client_id,
        invoice_number: freshbooks_data['invoice_number'],
        status: normalized_status,
        notes: freshbooks_data['notes'],
        invoice_id: invoice.id
      }
    end

    def normalize_status(status)
      return nil if status.blank?

      # Convert numeric status to string for database consistency
      InvoiceStatusConverter.to_string_safe(status) || status.to_s
    end

    def build_financial_attributes
      {
        amount: extract_amount(freshbooks_data['amount']),
        amount_outstanding: extract_amount(freshbooks_data['outstanding'] || freshbooks_data['amount_outstanding']),
        currency_code: freshbooks_data.dig('amount', 'code') || freshbooks_data['currency_code']
      }
    end

    def build_metadata
      {
        date: parse_date(freshbooks_data['create_date'] || freshbooks_data['date']),
        due_date: parse_date(freshbooks_data['due_date']),
        pdf_url: invoice_url || extract_invoice_url,
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

    def extract_invoice_url
      business_id = FreshbooksToken.current&.business_id || ENV.fetch('FRESHBOOKS_BUSINESS_ID', nil)
      invoice_id = freshbooks_data['id'] || freshbooks_data['invoiceid']
      return nil unless business_id && invoice_id

      "https://my.freshbooks.com/#/invoice/#{business_id}-#{invoice_id}"
    end
  end
end
