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
  validates :image, presence: true

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
end
