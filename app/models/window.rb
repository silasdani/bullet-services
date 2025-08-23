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
    return nil unless image.attached?

    window_number = window_schedule_repair.windows.order(:created_at).index(self) + 1
    "window-#{window_number}-image"
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

  rails_admin do
    object_label_method do
      :location
    end
  end

  private

  def image_presence
    # Only validate if this is an update and we're not skipping validation
    return if skip_image_validation
    return unless persisted? # Skip on creation

    # Only require image if it was previously attached and now missing
    if image_was_attached? && !image.attached?
      errors.add(:image, 'must be present')
    end
  end

  def image_was_attached?
    # Check if image was previously attached (for updates)
    respond_to?(:image_attachment_was) && image_attachment_was.present?
  end
end
