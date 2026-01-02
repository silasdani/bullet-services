# frozen_string_literal: true

module Freshbooks
  class SyncInvoicesJob < ApplicationJob
    queue_as :default

    retry_on FreshbooksError, wait: ->(executions) { (2**executions) + 1 }, attempts: 3
    discard_on ActiveRecord::RecordNotFound

    def perform(invoice_id = nil)
      invoices_service = Freshbooks::Invoices.new

      if invoice_id
        sync_single_invoice(invoices_service, invoice_id)
      else
        sync_all_invoices(invoices_service)
      end
    end

    private

    def sync_single_invoice(invoices_service, invoice_id)
      invoice_data = invoices_service.get(invoice_id)
      return unless invoice_data

      create_or_update_invoice(invoice_data)
    end

    def sync_all_invoices(invoices_service)
      page = 1
      errors = []

      loop do
        result = invoices_service.list(page: page, per_page: 100)
        invoices = result[:invoices]

        invoices.each do |invoice_data|
          create_or_update_invoice(invoice_data)
        rescue StandardError => e
          errors << "Invoice #{invoice_data['id']}: #{e.message}"
          Rails.logger.error("Failed to sync invoice #{invoice_data['id']}: #{e.message}")
        end

        break if page >= result[:pages]

        page += 1
      end

      Rails.logger.warn("Invoice sync completed with #{errors.length} errors") if errors.any?
    end

    def create_or_update_invoice(invoice_data)
      invoice = find_or_initialize_invoice(invoice_data)
      assign_invoice_attributes(invoice, invoice_data)
      invoice.save!

      # Use lifecycle service to ensure full reconciliation
      lifecycle_service = Freshbooks::InvoiceLifecycleService.new(invoice)
      lifecycle_service.reconcile_payments
      lifecycle_service.propagate_status_to_invoice
    rescue StandardError => e
      Rails.logger.error("Failed to sync invoice #{invoice_data['id']}: #{e.message}")
      raise
    end

    def find_or_initialize_invoice(invoice_data)
      FreshbooksInvoice.find_or_initialize_by(freshbooks_id: invoice_data['id'])
    end

    def assign_invoice_attributes(invoice, invoice_data)
      raw_status = invoice_data['status']
      normalized_status = normalize_status(raw_status)

      invoice.assign_attributes(
        freshbooks_client_id: invoice_data['clientid'],
        invoice_number: invoice_data['invoice_number'],
        status: normalized_status,
        amount: extract_amount(invoice_data['amount']),
        amount_outstanding: extract_amount(invoice_data['amount_outstanding']),
        date: parse_date(invoice_data['date']),
        due_date: parse_date(invoice_data['due_date']),
        currency_code: invoice_data.dig('amount', 'code'),
        notes: invoice_data['notes'],
        pdf_url: build_pdf_url(invoice_data['id']),
        raw_data: invoice_data
      )
    end

    def normalize_status(status)
      return nil if status.blank?

      # Convert numeric status to string for database consistency
      InvoiceStatusConverter.to_string_safe(status) || status.to_s
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

    def build_pdf_url(invoice_id)
      business_id = FreshbooksToken.current&.business_id
      return nil unless business_id

      "https://my.freshbooks.com/#/invoices/#{business_id}/#{invoice_id}/pdf"
    end
  end
end
