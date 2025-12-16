# frozen_string_literal: true

module Webflow
  # Service for handling PDF mirroring from Webflow
  class PdfMirrorService < ApplicationService
    attribute :record
    attribute :source_url
    attribute :attachment_name

    def call
      return if source_url.blank?
      return unless record.respond_to?(attachment_name)

      ActiveRecord::Base.connection_pool.with_connection do
        mirror_pdf
      end
    end

    private

    def mirror_pdf
      attachment = record.public_send(attachment_name)

      if attachment.respond_to?(:attached?) && attachment.attached?
        return if already_mirrored?(attachment)

        attachment.purge
      end

      download_and_attach_pdf(attachment)
    end

    def already_mirrored?(attachment)
      case attachment
      when ActiveStorage::Attached::One
        current = attachment.blob
        current&.metadata.is_a?(Hash) && current.metadata['source_url'] == source_url
      when ActiveStorage::Attached::Many
        blobs = attachment.blobs
        blobs.any? { |b| b.metadata.is_a?(Hash) && b.metadata['source_url'] == source_url }
      else
        false
      end
    end

    def download_and_attach_pdf(attachment)
      io = download_pdf(source_url)
      filename = extract_filename_with_fallback

      return cleanup_io(io) unless validate_pdf_content(io)

      blob = create_pdf_blob(io, filename)
      attach_blob_with_retry(attachment, blob)
    ensure
      cleanup_io(io)
    end

    def validate_pdf_content(io)
      io.rewind
      first_bytes = io.read(4)
      io.rewind

      return true if first_bytes == '%PDF'

      log_error("Downloaded content is not a valid PDF (starts with: #{first_bytes.inspect}). URL: #{source_url}")
      false
    end

    def create_pdf_blob(io, filename)
      io.rewind
      metadata = { source_url: source_url }

      ActiveRecord::Base.uncached do
        ActiveStorage::Blob.create_and_upload!(
          io: io,
          filename: filename,
          content_type: 'application/pdf',
          metadata: metadata
        )
      end
    end

    def cleanup_io(io)
      return unless io

      io.close
      io.unlink if io.respond_to?(:unlink)
    end

    def extract_filename_with_fallback
      uri = URI.parse(source_url)
      filename = File.basename(uri.path)

      if should_use_fallback_filename?(filename)
        generate_fallback_filename
      else
        ensure_pdf_extension(filename)
      end
    end

    def should_use_fallback_filename?(filename)
      filename.blank? || filename == '/' || filename == '\\'
    end

    def generate_fallback_filename
      record_type = record.class.name.downcase
      record_id = record.id
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      "#{record_type}_#{record_id}_#{timestamp}.pdf"
    end

    def ensure_pdf_extension(filename)
      filename.downcase.end_with?('.pdf') ? filename : "#{filename}.pdf"
    end

    def attach_blob_with_retry(attachment, blob)
      attempts = 0
      begin
        unless ActiveStorage::Blob.where(id: blob.id).exists?
          raise ActiveRecord::RecordNotFound, 'Blob not persisted yet'
        end

        attachment.attach(blob)
      rescue ActiveRecord::InvalidForeignKey, PG::ForeignKeyViolation, ActiveRecord::RecordNotFound => e
        attempts += 1
        if attempts <= 3
          sleep 0.2
          blob.reload if blob.persisted?
          retry
        else
          log_error("Skipping attach due to FK error for blob ##{blob.id}: #{e.class} - #{e.message}")
          nil
        end
      end
    end

    def download_pdf(url)
      uri = validate_and_parse_url(url)
      download_to_tempfile(uri)
    end

    def validate_and_parse_url(url)
      uri = URI.parse(url)
      raise ArgumentError, 'Only HTTPS is allowed' unless uri.is_a?(URI::HTTPS)

      uri
    end

    def download_to_tempfile(uri)
      tempfile = create_tempfile(uri)
      perform_http_download(uri, tempfile)
      tempfile.rewind
      tempfile
    end

    def create_tempfile(uri)
      Tempfile.new(['webflow_pdf', File.extname(uri.path) || '.pdf'], binmode: true)
    end

    def perform_http_download(uri, tempfile)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request_get(uri.request_uri) do |resp|
          validate_response_code(resp)
          resp.read_body { |chunk| tempfile.write(chunk) }
        end
      end
    end

    def validate_response_code(resp)
      return if resp.code.to_i.between?(200, 299)

      raise "Failed to download PDF: HTTP #{resp.code}"
    end
  end
end
