# frozen_string_literal: true

class MirrorWebflowImageJob < ApplicationJob
  queue_as :default

  # Arguments:
  #   record_class: String name of the AR class ("Window" or "WindowScheduleRepair")
  #   record_id: ID of the record to attach to
  #   source_url: Full HTTPS URL on Webflow's CDN to mirror
  #   attachment_name: Symbol/String for the ActiveStorage attachment (e.g., :image or :images)
  def perform(record_class, record_id, source_url, attachment_name)
    return if source_url.blank?

    record = record_class.constantize.find_by(id: record_id)
    return unless record

    # Skip if already mirrored (heuristic: check existing attachment present)
    if record.respond_to?(attachment_name)
      attachment = record.public_send(attachment_name)
      return if attachment.respond_to?(:attached?) && attachment.attached?
    end

    io = open_uri_for(source_url)

    filename = File.basename(URI.parse(source_url).path)
    content_type = Marcel::MimeType.for(io)

    if record.respond_to?(attachment_name)
      attachment = record.public_send(attachment_name)
      if attachment.is_a?(ActiveStorage::Attached::Many)
      end
      attachment.attach(io: io, filename: filename, content_type: content_type)
    end
  rescue StandardError => e
    Rails.logger.error("MirrorWebflowImageJob failed for #{record_class}(#{record_id}): #{e.class} - #{e.message}")
    raise e
  end

  private

  def open_uri_for(url)
    uri = URI.parse(url)
    raise ArgumentError, 'Only HTTPS is allowed' unless uri.is_a?(URI::HTTPS)

    # Stream into Tempfile to avoid loading full file into memory
    tempfile = Tempfile.new(['webflow', File.extname(uri.path)], binmode: true)
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
