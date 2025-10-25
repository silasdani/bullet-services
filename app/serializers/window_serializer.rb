class WindowSerializer < ActiveModel::Serializer
  attributes :id,
             :location,
             :created_at,
             :updated_at,
             :tools,
             :image,                # backwards-compatible field    # stored Webflow URL fallback
             :effective_image_url,  # preferred URL (ActiveStorage if present, else Webflow)
             :image_name

  has_many :tools, serializer: ToolSerializer

  # Backwards-compatible: return the effective image URL
  def image
    safe_call { object.effective_image_url }
  end

  def image_url
    safe_call { object.image_url }
  end

  def webflow_image_url
    safe_call { object.webflow_image_url }
  end

  def effective_image_url
    safe_call { object.effective_image_url }
  end

  def image_name
    safe_call { object.image_name }
  end

  private

  def safe_call
    yield
  rescue => e
    Rails.logger.error "Error serializing window image field: #{e.message}"
    nil
  end
end
