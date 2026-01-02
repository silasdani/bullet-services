# frozen_string_literal: true

module Wrs
  # Service for attaching PDFs to invoices from base64 data or URLs
  class PdfAttachmentService
    def initialize(invoice, pdf_data)
      @invoice = invoice
      @pdf_data = pdf_data
    end

    def call
      return if pdf_data.blank?

      if pdf_data[:base64].present?
        attach_from_base64(pdf_data[:base64])
      elsif pdf_data[:url].present?
        attach_from_url(pdf_data[:url])
      end
    end

    private

    attr_reader :invoice, :pdf_data

    def attach_from_base64(base64_data)
      Rails.logger.info("Attempting to attach PDF from base64 data (length: #{base64_data.length})")
      attach_invoice_pdf_from_base64!(base64_data)
    end

    def attach_from_url(pdf_url)
      if ui_route?(pdf_url)
        log_ui_route_skip(pdf_url)
      else
        Rails.logger.info("Attempting to attach PDF from URL: #{pdf_url}")
        attach_invoice_pdf!(pdf_url)
      end
    end

    def ui_route?(pdf_url)
      pdf_url.include?('/#/') || pdf_url.include?('/invoice/')
    end

    def log_ui_route_skip(pdf_url)
      Rails.logger.warn("Skipping PDF download from UI route (will return HTML): #{pdf_url}")
      Rails.logger.info('Users can download PDF directly from FreshBooks using the invoice_pdf_link')
    end

    def attach_invoice_pdf!(pdf_url)
      return if pdf_url.blank?

      Webflow::PdfMirrorService.new(
        record: invoice,
        source_url: pdf_url,
        attachment_name: :invoice_pdf
      ).call
    end

    def attach_invoice_pdf_from_base64!(base64_data)
      return if base64_data.blank?

      tempfile = nil
      begin
        pdf_bytes = decode_and_validate_pdf(base64_data)
        return unless pdf_bytes

        tempfile = create_pdf_tempfile(pdf_bytes)
        attach_pdf_with_retries(tempfile)
      rescue StandardError => e
        Rails.logger.error("Failed to attach PDF from base64: #{e.message}")
        Rails.logger.error("Error class: #{e.class}")
        Rails.logger.error("Backtrace: #{e.backtrace.first(10).join('\n')}")
      ensure
        cleanup_tempfile(tempfile)
      end
    end

    def decode_and_validate_pdf(base64_data)
      Rails.logger.info("Decoding base64 PDF data (length: #{base64_data.length})")
      pdf_bytes = Base64.decode64(base64_data)
      Rails.logger.info("Decoded PDF bytes length: #{pdf_bytes.length}")

      return pdf_bytes if pdf_bytes.start_with?('%PDF')

      log_invalid_pdf_error(pdf_bytes)
      nil
    rescue StandardError => e
      Rails.logger.error("Failed to decode base64 PDF data: #{e.message}")
      nil
    end

    def log_invalid_pdf_error(pdf_bytes)
      first_bytes = safe_read_first_bytes(pdf_bytes)
      Rails.logger.error('Base64 data does not appear to be a valid PDF')
      Rails.logger.error("First bytes: #{first_bytes.inspect}")
    end

    def safe_read_first_bytes(pdf_bytes)
      pdf_bytes[0..20]
    rescue StandardError
      'unable to read'
    end

    def create_pdf_tempfile(pdf_bytes)
      tempfile = Tempfile.new(['invoice_pdf', '.pdf'], binmode: true)
      tempfile.write(pdf_bytes)
      tempfile.rewind
      Rails.logger.info('Created tempfile with PDF data')
      tempfile
    end

    def attach_pdf_with_retries(tempfile)
      reload_invoice_if_persisted
      attachment_success = attempt_attachment_with_retries(tempfile)
      log_attachment_success(attachment_success)
    rescue StandardError => e
      log_attachment_failure(e)
      raise
    end

    def reload_invoice_if_persisted
      invoice.reload if invoice.persisted?
    end

    def attempt_attachment_with_retries(tempfile)
      max_retries = 3
      retry_count = 0
      attachment_success = false

      while retry_count < max_retries && !attachment_success
        attachment_success = attempt_pdf_attachment(tempfile, retry_count, max_retries)
        retry_count += 1 unless attachment_success
      end

      attachment_success
    end

    def log_attachment_success(attachment_success)
      return unless attachment_success

      Rails.logger.info(
        "Successfully attached PDF from base64 data to invoice #{invoice.id}"
      )
    end

    def log_attachment_failure(error)
      Rails.logger.error("Failed to attach PDF: #{error.message}")
      Rails.logger.error("Error class: #{error.class}")
    end

    def attempt_pdf_attachment(tempfile, retry_count, max_retries)
      # Use create_and_upload! to ensure the file is uploaded to S3 before creating the blob record
      tempfile.rewind
      filename = "invoice_#{invoice.slug}_#{Time.current.to_i}.pdf"

      blob = ActiveStorage::Blob.create_and_upload!(
        io: tempfile,
        filename: filename,
        content_type: 'application/pdf',
        metadata: { source: 'freshbooks_api_base64' }
      )

      # Verify the blob exists in S3 before attaching
      unless blob.service.exist?(blob.key)
        blob.purge
        raise "PDF upload failed: File does not exist in S3 storage (blob key: #{blob.key})"
      end

      # Now attach the verified blob to the invoice
      invoice.invoice_pdf.attach(blob)

      # Double-check attachment
      return false unless attachment_verified?

      Rails.logger.info("Successfully attached and verified PDF blob #{blob.key} in S3")
      true
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      handle_attachment_error(e, tempfile, retry_count, max_retries)
      false
    rescue StandardError => e
      Rails.logger.error("Error in attempt_pdf_attachment: #{e.class}: #{e.message}")
      handle_attachment_error(e, tempfile, retry_count, max_retries)
      false
    end

    def attachment_verified?
      invoice.reload
      return false unless invoice.invoice_pdf.attached?

      blob = invoice.invoice_pdf.blob
      Rails.logger.info("PDF attachment verified: #{blob.filename}, size: #{blob.byte_size} bytes")
      true
    end

    def handle_attachment_error(error, tempfile, retry_count, max_retries)
      raise if retry_count >= max_retries - 1

      Rails.logger.warn("Attachment error: #{error.message}, retrying (#{retry_count + 1}/#{max_retries})...")
      sleep(0.5)
      tempfile&.rewind
    end

    def cleanup_tempfile(tempfile)
      return unless tempfile

      tempfile.close
    rescue StandardError
      nil
    ensure
      begin
        tempfile&.unlink
      rescue StandardError
        nil
      end
    end
  end
end
