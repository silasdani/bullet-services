# frozen_string_literal: true

module Webflow
  # Service for handling image mirroring from Webflow
  class ImageMirrorService < ApplicationService
    attribute :record
    attribute :source_url
    attribute :attachment_name

    def call
      return if source_url.blank?
      return unless record.respond_to?(attachment_name)

      ActiveRecord::Base.connection_pool.with_connection do
        mirror_image
      end
    end

    private

    def mirror_image
      attachment = record.public_send(attachment_name)

      if attachment.respond_to?(:attached?) && attachment.attached?
        return if already_mirrored?(attachment)
        attachment.purge
      end

      download_and_attach_image(attachment)
    end

    def already_mirrored?(attachment)
      case attachment
      when ActiveStorage::Attached::One
        current = attachment.blob
        current&.metadata.is_a?(Hash) && current.metadata["source_url"] == source_url
      when ActiveStorage::Attached::Many
        blobs = attachment.blobs
        blobs.any? { |b| b.metadata.is_a?(Hash) && b.metadata["source_url"] == source_url }
      else
        false
      end
    end

    def download_and_attach_image(attachment)
      io = download_image(source_url)
      filename = File.basename(URI.parse(source_url).path)
      io.rewind
      content_type = Marcel::MimeType.for(io)
      io.rewind

      metadata = { source_url: source_url }
      blob = nil

      ActiveRecord::Base.uncached do
        blob = ActiveStorage::Blob.create_and_upload!(
          io: io,
          filename: filename,
          content_type: content_type,
          metadata: metadata
        )
      end

      attach_blob_with_retry(attachment, blob)
    end

    def attach_blob_with_retry(attachment, blob)
      attempts = 0
      begin
        unless ActiveStorage::Blob.where(id: blob.id).exists?
          raise ActiveRecord::RecordNotFound, "Blob not persisted yet"
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

    def download_image(url)
      uri = URI.parse(url)
      raise ArgumentError, "Only HTTPS is allowed" unless uri.is_a?(URI::HTTPS)

      tempfile = Tempfile.new([ "webflow", File.extname(uri.path) ], binmode: true)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request_get(uri.request_uri) do |resp|
          raise "Failed to download image: HTTP #{resp.code}" unless resp.code.to_i.between?(200, 299)
          resp.read_body { |chunk| tempfile.write(chunk) }
        end
      end
      tempfile.rewind
      tempfile
    end
  end
end
