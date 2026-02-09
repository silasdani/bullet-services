# frozen_string_literal: true

class Window < ApplicationRecord
  belongs_to :window_schedule_repair
  has_many :tools, dependent: :destroy
  has_many_attached :images

  accepts_nested_attributes_for :tools, allow_destroy: true, reject_if: :all_blank

  # Add safety for nested attributes
  def tools_attributes=(attributes)
    super(attributes.reject { |_, v| v.blank? })
  end

  validates :location, presence: true
  validate :images_presence, unless: :skip_image_validation, on: :update, if: :persisted?

  # Attribute to skip image validation during creation
  attr_accessor :skip_image_validation

  # Backwards compatibility: return first image
  def image
    images.first
  end

  def image_name
    return nil unless images.attached?

    window_number = window_schedule_repair.windows.order(:created_at).index(self) + 1
    "window-#{window_number}-image"
  end

  # Generate public URL for the first image (backwards compatibility)
  def image_url
    return nil unless images.attached?

    images.first.url
  rescue StandardError => e
    Rails.logger.error "Error generating image URL: #{e.message}"
    nil
  end

  # Generate URLs for all images
  def image_urls
    return [] unless images.attached?

    images.map(&:url)
  rescue StandardError => e
    Rails.logger.error "Error generating image URLs: #{e.message}"
    []
  end

  # Check if any image is attached (for compatibility)
  def image_attached?
    images.attached?
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
    rescue StandardError => e
      Rails.logger.error "Error calculating window total price: #{e.message}"
      0
    end
  end

  # Prefer S3 URL if mirrored, otherwise fall back to Webflow URL
  # Returns first image URL for backwards compatibility
  def effective_image_url
    if images.attached?
      Rails.logger.debug "Window ##{id}: Using ActiveStorage image"
      image_url
    else
      url = extract_webflow_url(webflow_image_url)
      Rails.logger.debug "Window ##{id}: No ActiveStorage image, using webflow_image_url: #{url.inspect}"
      url
    end
  rescue StandardError => e
    Rails.logger.error "Window ##{id}: Error in effective_image_url: #{e.message}"
    nil
  end

  # Returns all effective image URLs
  def effective_image_urls
    urls = []

    urls.concat(image_urls) if images.attached?

    webflow_url = extract_webflow_url(webflow_image_url)
    urls << webflow_url if webflow_url.present?

    urls.compact.uniq
  rescue StandardError => e
    Rails.logger.error "Window ##{id}: Error in effective_image_urls: #{e.message}"
    []
  end

  # Extract URL from webflow_image_url field
  # Handles both string URLs and accidentally stringified hashes
  def extract_webflow_url(value)
    return nil if value.blank?

    # If it's already a clean URL, return it
    return value if value.is_a?(String) && value.start_with?('http')

    # If it looks like a stringified hash, try to extract the URL
    if value.is_a?(String) && value.include?('"url"')
      # Extract URL from stringified hash like: {"url" => "https://...", ...}
      match = value.match(/"url"\s*=>\s*"([^"]+)"/)
      return match[1] if match
    end

    # Fallback: return as-is
    value
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[location window_schedule_repair_id created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[window_schedule_repair tools]
  end

  private

  def images_presence
    # Only validate if this is an update and we're not skipping validation
    return if skip_image_validation
    return unless persisted? # Skip on creation

    # Only require images if they were previously present and now missing
    return unless images_were_present? && !images.attached?

    errors.add(:images, 'must be present')
  end

  def images_were_present?
    # Check if images were previously present (for updates)
    respond_to?(:images_was) && images_was.present?
  end
end
