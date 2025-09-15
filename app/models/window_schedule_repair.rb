class WindowScheduleRepair < ApplicationRecord
  include Wrs

  belongs_to :user
  has_many :windows, dependent: :destroy
  has_many :tools, through: :windows
  has_many_attached :images

  accepts_nested_attributes_for :windows, allow_destroy: true, reject_if: :all_blank

  # Add safety for nested attributes
  def windows_attributes=(attributes)
    super(attributes.reject { |_, v| v.blank? })
  end

  enum :status, pending: 0, approved: 1, rejected: 2, completed: 3

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :address, presence: true

  before_save :calculate_totals
  before_validation :generate_slug, on: :create

  scope :for_user, ->(user) {
    case user.role
    when 'admin'
      all
    when 'employee'
      where(user: user)
    when 'client'
      where(user: user)
    end
  }

  def calculate_totals
    # Calculate subtotal more safely with additional error handling
    begin
      subtotal = 0
      if windows.any?
        windows.each do |window|
          if window.tools.any?
            window.tools.each do |tool|
              subtotal += tool.price.to_f if tool.price
            end
          end
        end
      end

      self.total_vat_excluded_price = subtotal
      self.total_vat_included_price = (subtotal * 1.2).round(2) # 20% VAT
      self.grand_total = total_vat_included_price
    rescue => e
      # Fallback values if calculation fails
      Rails.logger.error "Error calculating totals: #{e.message}"
      self.total_vat_excluded_price = 0
      self.total_vat_included_price = 0
      self.grand_total = 0
    end
  end

  def subtotal
    # Calculate subtotal more safely with additional error handling
    begin
      subtotal = 0
      if windows.any?
        windows.each do |window|
          if window.tools.any?
            window.tools.each do |tool|
              subtotal += tool.price.to_f if tool.price
            end
          end
        end
      end
      subtotal
    rescue => e
      Rails.logger.error "Error calculating subtotal: #{e.message}"
      0
    end
  end

  def vat_amount
    return 0 if total_vat_included_price.nil? || total_vat_excluded_price.nil?
    begin
      total_vat_included_price - total_vat_excluded_price
    rescue => e
      Rails.logger.error "Error calculating VAT amount: #{e.message}"
      0
    end
  end

  def status_color
    case status
    when 'pending'
      '#FFA500' # Orange for pending
    when 'approved'
      '#00FF00' # Green for approved
    when 'rejected'
      '#FF0000' # Red for rejected
    when 'completed'
      '#0000FF' # Blue for completed
    else
      '#FFA500' # Default orange for pending
    end
  end

  private

  def generate_slug
    self.slug = "#{name.parameterize}-#{SecureRandom.hex(4)}" if slug.blank?
  end

  # Ransack configuration for filtering
  def self.ransackable_attributes(auth_object = nil)
    %w[name slug flat_number reference_number address details status created_at updated_at total_vat_included_price total_vat_excluded_price grand_total]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user windows tools]
  end

  rails_admin do
    object_label_method do
      :name
    end
  end
end
