class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :name, :nickname, :role, :created_at, :updated_at

  attribute :image_url, if: :image_attached?

  def image_url
    Rails.application.routes.url_helpers.rails_blob_path(object.image, only_path: true)
  end

  def image_attached?
    object.image.attached?
  end
end
