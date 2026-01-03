# frozen_string_literal: true

module Webflow
  # Service for handling PDF mirroring from Webflow
  # rubocop:disable Metrics/ClassLength
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
      io = nil
      begin
        io = download_pdf(source_url)
        filename = extract_filename_with_fallback

        unless valid_pdf_content?(io)
          cleanup_io(io)
          return
        end

        # Ensure IO is at the beginning before upload
        io.rewind

        blob = create_pdf_blob(io, filename)
        verify_blob_upload(blob)
        attach_blob_with_retry(attachment, blob)
      ensure
        cleanup_io(io) if io
      end
    end

    def valid_pdf_content?(io)
      io.rewind
      first_bytes = io.read(4)
      io.rewind

      return true if first_bytes == '%PDF'

      log_error("Downloaded content is not a valid PDF (starts with: #{first_bytes.inspect}). URL: #{source_url}")
      false
    end

    def create_pdf_blob(io, filename)
      # Ensure IO is rewound before upload
      io.rewind
      metadata = { source_url: source_url }

      # Create blob and upload - create_and_upload! reads the IO and uploads to S3
      blob = nil
      ActiveRecord::Base.uncached do
        blob = ActiveStorage::Blob.create_and_upload!(
          io: io,
          filename: filename,
          content_type: 'application/pdf',
          metadata: metadata
        )
      end

      log_info("Created blob #{blob.key} for #{filename} (#{blob.byte_size} bytes)")
      blob
    rescue StandardError => e
      log_error("Failed to create and upload blob: #{e.class}: #{e.message}")
      log_error("Backtrace: #{e.backtrace.first(5).join("\n")}")
      raise
    end

    def verify_blob_upload(blob)
      return if blob.service.exist?(blob.key)

      log_error("Blob #{blob.key} was created but file does not exist in storage")
      blob.purge
      raise "Failed to upload blob #{blob.key} to storage"
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
      max_attempts = 3

      loop do
        verify_blob_persisted(blob)
        attach_blob(attachment, blob)
        return blob
      rescue ActiveRecord::InvalidForeignKey, PG::ForeignKeyViolation, ActiveRecord::RecordNotFound => e
        attempts += 1
        if attempts <= max_attempts
          sleep 0.2
          blob.reload if blob.persisted?
        else
          log_error("Failed to attach blob ##{blob.id} after #{attempts} attempts: #{e.class} - #{e.message}")
          cleanup_orphaned_blob(blob)
          return nil
        end
      rescue StandardError => e
        handle_attachment_error(e, blob)
      end
    end

    def verify_blob_persisted(blob)
      return if ActiveStorage::Blob.where(id: blob.id).exists?

      raise ActiveRecord::RecordNotFound, 'Blob not persisted yet'
    end

    def attach_blob(attachment, blob)
      attachment.attach(blob)
      log_info("Successfully attached blob #{blob.key} to #{record.class.name} ##{record.id}")
    end

    def handle_attachment_error(error, blob)
      log_error("Unexpected error attaching blob ##{blob.id}: #{error.class} - #{error.message}")
      cleanup_orphaned_blob(blob)
      raise
    end

    def cleanup_orphaned_blob(blob)
      return unless blob&.persisted?

      begin
        log_info("Cleaning up orphaned blob #{blob.key}")
        blob.purge
      rescue StandardError => e
        log_error("Failed to cleanup orphaned blob #{blob.key}: #{e.message}")
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
      download_with_http(uri, tempfile)
    rescue Net::TimeoutError, Net::OpenTimeout, Net::ReadTimeout => e
      handle_download_timeout(uri, e)
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
      handle_download_connection_error(uri, e)
    rescue StandardError => e
      handle_download_error(uri, e)
    end

    def download_with_http(uri, tempfile)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request['User-Agent'] = 'Bullet Services/1.0'

        http.request(request) do |resp|
          validate_response_code(resp)
          write_response_to_tempfile(resp, tempfile)
        end
      end
    end

    def write_response_to_tempfile(resp, tempfile)
      resp.read_body { |chunk| tempfile.write(chunk) }
      tempfile.flush
    end

    def handle_download_timeout(uri, error)
      log_error("Timeout downloading PDF from #{uri}: #{error.message}")
      raise "PDF download timed out: #{error.message}"
    end

    def handle_download_connection_error(uri, error)
      log_error("Connection error downloading PDF from #{uri}: #{error.message}")
      raise "Failed to connect to PDF server: #{error.message}"
    end

    def handle_download_error(uri, error)
      log_error("Unexpected error downloading PDF from #{uri}: #{error.class}: #{error.message}")
      raise
    end

    def validate_response_code(resp)
      return if resp.code.to_i.between?(200, 299)

      error_msg = "Failed to download PDF: HTTP #{resp.code}"
      error_msg += " - #{resp.body[0..200]}" if resp.body.present?
      raise error_msg
    end
  end
  # rubocop:enable Metrics/ClassLength
end
