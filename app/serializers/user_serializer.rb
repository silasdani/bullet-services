# frozen_string_literal: true

class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :name, :nickname, :role, :assigned_building_ids, :created_at, :updated_at

  attribute :image_url, if: :image_attached?

  def assigned_building_ids
    # Keep payload small + stable (ids only). Use pluck to avoid N+1.
    object.building_assignments.pluck(:building_id)
  rescue StandardError
    []
  end

  def image_url
    Rails.application.routes.url_helpers.rails_blob_path(object.image, only_path: true)
  end

  def image_attached?
    object.image.attached?
  end
end
