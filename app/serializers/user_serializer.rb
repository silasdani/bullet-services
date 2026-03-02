# frozen_string_literal: true

class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :first_name, :last_name, :name, :phone_no, :nickname, :role,
             :assigned_building_ids, :created_at, :updated_at

  attribute :image_url, if: :image_attached?

  def assigned_building_ids
    object.assignments.pluck(:building_id)
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
