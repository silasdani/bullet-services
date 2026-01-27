# frozen_string_literal: true

module ImageSerializable
  extend ActiveSupport::Concern

  def image_urls(images_collection)
    return [] unless images_collection.attached?

    images_collection.map do |img|
      Rails.application.routes.url_helpers.rails_blob_path(img, only_path: true)
    end
  end
end
