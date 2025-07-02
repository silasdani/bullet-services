class UserSerializer < ActiveModel::Serializer
  attributes :id, :email, :name, :nickname, :role, :created_at, :updated_at, :image_url

  def image_url
    return nil unless object.image.attached?
    Rails.application.routes.url_helpers.url_for(object.image)
  end
end