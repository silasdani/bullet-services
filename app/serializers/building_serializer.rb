# frozen_string_literal: true

class BuildingSerializer < ActiveModel::Serializer
  attributes :id, :name, :street, :city, :country, :zipcode,
             :latitude, :longitude,
             :created_at, :updated_at, :deleted_at

  # Address string representation
  attribute :address_string do
    object.address_string
  end

  attribute :full_address do
    object.full_address
  end

  attribute :display_name do
    object.display_name
  end

  # Count of work orders for this building
  # Use size to avoid extra query if association is loaded, otherwise use count
  attribute :wrs_count do
    if object.association(:work_orders).loaded?
      object.work_orders.size
    else
      object.work_orders.count
    end
  end

  attribute :schedule_of_condition_notes

  attribute :schedule_of_condition_images do
    next [] unless object.schedule_of_condition_images.attached?

    default_host = Rails.application.config.action_mailer.default_url_options[:host]
    default_port = Rails.application.config.action_mailer.default_url_options[:port]
    protocol = Rails.env.production? ? 'https' : 'http'

    object.schedule_of_condition_images.map do |attachment|
      url_options = { host: default_host, protocol: protocol }
      url_options[:port] = default_port if default_port.present?
      url = Rails.application.routes.url_helpers.rails_blob_url(attachment, **url_options)
      {
        id: attachment.id,
        url: url
      }
    rescue StandardError => e
      Rails.logger.error "Error generating image URL for building #{object.id}: #{e.message}"
      begin
        url = attachment.url
        {
          id: attachment.id,
          url: url
        }
      rescue StandardError
        nil
      end
    end.compact
  end
end
