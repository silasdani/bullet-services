class WindowSerializer < ActiveModel::Serializer
  attributes :id, :image, :location, :created_at, :updated_at

  has_many :tools, serializer: ToolSerializer

  # Handle image properly with error handling
  def image
    return nil unless object.respond_to?(:image)

    begin
      if object.image.present?
        object.image.url
      else
        nil
      end
    rescue => e
      Rails.logger.error "Error serializing window image: #{e.message}"
      nil
    end
  end
end
