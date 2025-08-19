class WindowSerializer < ActiveModel::Serializer
  attributes :id, :image, :location, :created_at, :updated_at

  has_many :tools, serializer: ToolSerializer
  
  # Handle image attachment properly with error handling
  def image
    return nil unless object.respond_to?(:image)
    
    begin
      if object.image.attached?
        {
          url: Rails.application.routes.url_helpers.rails_blob_url(object.image),
          filename: object.image.filename,
          content_type: object.image.content_type,
          byte_size: object.image.byte_size,
          attached: true
        }
      else
        nil
      end
    rescue => e
      Rails.logger.error "Error serializing window image: #{e.message}"
      nil
    end
  end
end
