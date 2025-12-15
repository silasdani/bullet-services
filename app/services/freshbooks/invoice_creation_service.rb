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

      # Try to get PDF data from FreshBooks API
      # The API might return base64 PDF data or a download URL
      pdf_base64_data = nil
      pdf_download_url = nil

      begin
        # Strategy 1: Try to get PDF as binary and convert to base64 (with retries)
        pdf_binary = nil
        3.times do |attempt|
          pdf_binary = invoices_client.get_pdf_binary(freshbooks_invoice_id)
          break if pdf_binary.present? && pdf_binary.start_with?('%PDF')
        rescue StandardError => e
          log_warn("PDF binary fetch attempt #{attempt + 1} failed: #{e.message}")
          sleep(0.5) if attempt < 2 # Wait before retry
        end

        if pdf_binary.present? && pdf_binary.start_with?('%PDF')
          pdf_base64_data = Base64.strict_encode64(pdf_binary)
          log_info("Successfully retrieved PDF binary (#{pdf_binary.length} bytes) and encoded to base64")
        end

        # Strategy 2: If binary failed, try JSON API endpoint for base64
        unless pdf_base64_data.present?
          pdf_base64_data = invoices_client.get_pdf_as_base64(freshbooks_invoice_id)
          log_info("PDF base64 from JSON API length: #{pdf_base64_data&.length}")
        end

        # Strategy 3: If no base64, try to get download URL from JSON response
        unless pdf_base64_data.present?
          pdf_data = invoices_client.get_pdf(freshbooks_invoice_id)
          log_info("PDF data from FreshBooks API: #{pdf_data.class} - #{pdf_data.inspect[0..200]}")

          if pdf_data.is_a?(String) && pdf_data.length > 100
            # Might be base64 string
            begin
              decoded = Base64.decode64(pdf_data)
              if decoded.start_with?('%PDF')
                pdf_base64_data = pdf_data
                log_info('Found base64 PDF in string response')
              end
            rescue StandardError
              # Not base64, continue
            end
          end

          pdf_download_url = extract_pdf_download_url(pdf_data) if pdf_data.is_a?(Hash)
          log_info("Extracted PDF download URL: #{pdf_download_url.inspect}")
        end
      rescue StandardError => e
        log_error("Failed to get PDF from FreshBooks API: #{e.message}")
        log_error("Error class: #{e.class}")
        log_error("Error backtrace: #{e.backtrace.first(5).join('\n')}")
      end

      # Final fallback: Try to fetch PDF using direct API endpoint with binary request
      unless pdf_base64_data.present?
        begin
          pdf_binary_fallback = invoices_client.get_pdf_binary(freshbooks_invoice_id)
          if pdf_binary_fallback.present? && pdf_binary_fallback.start_with?('%PDF')
            pdf_base64_data = Base64.strict_encode64(pdf_binary_fallback)
            log_info('Successfully retrieved PDF via binary fallback method')
          end
        rescue StandardError => e
          log_warn("Binary PDF fallback failed: #{e.message}")
        end

        # Last resort: construct URL (but we'll skip downloading from UI routes)
        pdf_download_url ||= extract_pdf_url(freshbooks_invoice_data) unless pdf_base64_data.present?
      end

      # Store the FreshBooks client ID and UI invoice URL
      invoice.update!(
        freshbooks_client_id: client_id,
        invoice_pdf_link: invoice_url
      )

      # Create or update local FreshbooksInvoice record
      sync_freshbooks_invoice_record(freshbooks_invoice_data, invoice_url)

      log_info("Created FreshBooks invoice #{freshbooks_invoice_id} for invoice #{invoice.id}")
      @result = {
        freshbooks_invoice: freshbooks_invoice_data,
        invoice: invoice,
        pdf_url: pdf_download_url,
        pdf_base64: pdf_base64_data,
        invoice_url: invoice_url
      }
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

      # Default line item from invoice amounts
      # If included_vat_amount is present, use it and mark as tax-inclusive
      # Otherwise use excluded_vat_amount (tax will be added by FreshBooks)
      cost = invoice.included_vat_amount || invoice.excluded_vat_amount || 0
      tax_included = invoice.included_vat_amount.present?

      [
        {
          name: invoice.name || 'Invoice',
          description: invoice.job || invoice.wrs_link || '',
          quantity: 1,
          cost: cost,
          type: 0, # Service
          tax_included: tax_included
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

    def extract_pdf_download_url(pdf_data)
      # Extract PDF download URL from FreshBooks API response
      # Response format might be: { "filename": "...", "file_url": "https://..." }
      # Or the PDF data might be nested differently
      return nil if pdf_data.nil?
      return nil unless pdf_data.is_a?(Hash)

      # Try various possible keys
      pdf_data['file_url'] ||
        pdf_data[:file_url] ||
        pdf_data['url'] ||
        pdf_data[:url] ||
        pdf_data.dig('pdf', 'file_url') ||
        pdf_data.dig('pdf', 'url')
    end

    def extract_pdf_url(freshbooks_data)
      # Direct FreshBooks PDF download URL (fallback)
      business_id = FreshbooksToken.current&.business_id || ENV.fetch('FRESHBOOKS_BUSINESS_ID', nil)
      invoice_id = freshbooks_data['id'] || freshbooks_data['invoiceid']
      return nil unless business_id && invoice_id

      "https://my.freshbooks.com/#/invoices/#{business_id}/#{invoice_id}/pdf"
    end

    def extract_invoice_url(freshbooks_data)
      # FreshBooks UI invoice URL (desired format)
      business_id = FreshbooksToken.current&.business_id || ENV.fetch('FRESHBOOKS_BUSINESS_ID', nil)
      invoice_id = freshbooks_data['id'] || freshbooks_data['invoiceid']
      return nil unless business_id && invoice_id

      "https://my.freshbooks.com/#/invoice/#{business_id}-#{invoice_id}"
    end

    def sync_freshbooks_invoice_record(freshbooks_data, invoice_url = nil)
      fb_invoice = find_or_initialize_fb_invoice(freshbooks_data)
      assign_fb_invoice_attributes(fb_invoice, freshbooks_data, invoice_url)
      fb_invoice.save!
    end

    def find_or_initialize_fb_invoice(freshbooks_data)
      invoice_id = freshbooks_data['id'] || freshbooks_data['invoiceid']
      FreshbooksInvoice.find_or_initialize_by(freshbooks_id: invoice_id)
    end

    def assign_fb_invoice_attributes(fb_invoice, freshbooks_data, invoice_url = nil)
      fb_invoice.assign_attributes(
        **build_fb_invoice_basic_attributes(freshbooks_data),
        **build_fb_invoice_financial_attributes(freshbooks_data),
        **build_fb_invoice_metadata(freshbooks_data, invoice_url)
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

    def build_fb_invoice_metadata(freshbooks_data, invoice_url = nil)
      {
        date: parse_date(freshbooks_data['create_date'] || freshbooks_data['date']),
        due_date: parse_date(freshbooks_data['due_date']),
        pdf_url: invoice_url || extract_invoice_url(freshbooks_data),
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
        message: 'Please find your invoice attached. You can pay online using your FreshBooks client portal.'
      )

      log_info("Sent invoice email to #{email_to} for FreshBooks invoice #{freshbooks_invoice_id}")
    end
  end
end
