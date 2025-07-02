class UserSerializer < ActiveModel::Serializer
  include Rails.application.routes.url_helpers
  attributes :id, :email, :name, :nickname, :role, :created_at, :updated_at

  attribute :image_url, if: :image_attached?
  def image_url
    url_for(object.image)
  end

  def image_attached?
    object.image.attached?
  end
end
