class QuotationSerializer < ActiveModel::Serializer
  attributes :id, :address, :details, :price, :status, :client_name,
             :client_phone, :client_email, :created_at, :updated_at, :images

  belongs_to :user, serializer: UserSerializer

  def images
    object.images.map do |image|
      {
        id: image.id,
        url: Rails.application.routes.url_helpers.url_for(image),
        filename: image.filename
      }
    end
  end
end