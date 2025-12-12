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

    record = find_record(record_class, record_id)
    return unless record
    return if already_attached?(record, attachment_name)

    attach_image_to_record(record, source_url, attachment_name)
  rescue StandardError => e
    handle_job_error(record_class, record_id, e)
    raise e
  end

  def find_record(record_class, record_id)
    record_class.constantize.find_by(id: record_id)
  end

  def already_attached?(record, attachment_name)
    return false unless record.respond_to?(attachment_name)

    attachment = record.public_send(attachment_name)
    attachment.respond_to?(:attached?) && attachment.attached?
  end

  def attach_image_to_record(record, source_url, attachment_name)
    return unless record.respond_to?(attachment_name)

    io = open_uri_for(source_url)
    filename = extract_filename(source_url)
    content_type = determine_content_type(io)

    attachment = record.public_send(attachment_name)
    attachment.attach(io: io, filename: filename, content_type: content_type)
  end

  def extract_filename(source_url)
    File.basename(URI.parse(source_url).path)
  end

  def determine_content_type(io)
    Marcel::MimeType.for(io)
  end

  def handle_job_error(record_class, record_id, error)
    Rails.logger.error("MirrorWebflowImageJob failed for #{record_class}(#{record_id}): " \
                       "#{error.class} - #{error.message}")
  end

  private

  def open_uri_for(url)
    uri = parse_and_validate_uri(url)
    tempfile = create_tempfile(uri)
    download_to_tempfile(uri, tempfile)
    tempfile.rewind
    tempfile
  end

  def parse_and_validate_uri(url)
    uri = URI.parse(url)
    raise ArgumentError, 'Only HTTPS is allowed' unless uri.is_a?(URI::HTTPS)

    uri
  end

  def create_tempfile(uri)
    Tempfile.new(['webflow', File.extname(uri.path)], binmode: true)
  end

  def download_to_tempfile(uri, tempfile)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request_get(uri.request_uri) do |resp|
        validate_response_code(resp)
        resp.read_body { |chunk| tempfile.write(chunk) }
      end
    end
  end

  def validate_response_code(resp)
    return if resp.code.to_i.between?(200, 299)

    raise "Failed to download image: HTTP #{resp.code}"
  end
end
