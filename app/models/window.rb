class Window < ApplicationRecord
  belongs_to :window_schedule_repair
  has_many :tools, dependent: :destroy
  has_one_attached :image

  accepts_nested_attributes_for :tools, allow_destroy: true, reject_if: :all_blank

  # Add safety for nested attributes
  def tools_attributes=(attributes)
    super(attributes.reject { |_, v| v.blank? })
  end

  validates :location, presence: true
  validate :image_presence, unless: :skip_image_validation, on: :update, if: :persisted?

  # Attribute to skip image validation during creation
  attr_accessor :skip_image_validation

  def image_name
    return nil unless image.present?

    window_number = window_schedule_repair.windows.order(:created_at).index(self) + 1
    "window-#{window_number}-image"
  end

  # Generate public URL for the image
  def image_url
    return nil unless image.present?

    image.url
  rescue => e
    Rails.logger.error "Error generating image URL: #{e.message}"
    nil
  end

  # Check if image is attached (for compatibility)
  def image_attached?
    image.present?
  end

  def tools_list
    tools.map(&:name).join(', ')
  end

  def tools_prices_list
    tools.map(&:price).join(', ')
  end

  def total_price
    return 0 if tools.empty?
    begin
      total = 0
      tools.each do |tool|
        total += tool.price.to_f if tool.price
      end
      total
    rescue => e
      Rails.logger.error "Error calculating window total price: #{e.message}"
      0
    end
  end

  # Prefer S3 URL if mirrored, otherwise fall back to Webflow URL
  def effective_image_url
    if image.attached?
      image_url
    else
      self.webflow_image_url
    end
  end


  private

  def image_presence
    # Only validate if this is an update and we're not skipping validation
    return if skip_image_validation
    return unless persisted? # Skip on creation

    # Only require image if it was previously present and now missing
    if image_was_present? && !image.present?
      errors.add(:image, 'must be present')
    end
  end

  def image_was_present?
    # Check if image was previously present (for updates)
    respond_to?(:image_was) && image_was.present?
  end
end
