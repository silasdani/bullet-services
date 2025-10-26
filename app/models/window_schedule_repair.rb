# frozen_string_literal: true

class WindowScheduleRepair < ApplicationRecord
  include Wrs
  include SoftDeletable
  include WebflowSyncable

  belongs_to :user
  has_many :windows, dependent: :destroy
  has_many :tools, through: :windows
  has_many_attached :images

  accepts_nested_attributes_for :windows, allow_destroy: true, reject_if: :all_blank

  enum :status, pending: 0, approved: 1, rejected: 2, completed: 3

  validates :name, presence: true
  validates :address, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create
  before_validation :generate_reference_number
  before_validation :set_default_webflow_flags, on: :create

  before_save :calculate_totals

  scope :for_user, lambda { |user|
    case user.role
    when 'admin'
      all
    when 'employee'
      where(user: user)
    when 'client'
      where(user: user)
    end
  }

  # Webflow-related scopes
  scope :published, -> { where(is_draft: false, is_archived: false) }
  scope :draft, -> { where(is_draft: true) }
  scope :archived, -> { where(is_archived: true) }

  # Return first S3 image URL if mirrored, otherwise fallback to Webflow URL stored
  def main_image_url
    if images.attached? && images.first.present?
      images.first.url
    else
      webflow_main_image_url
    end
  rescue StandardError => e
    Rails.logger.error "Error generating main image URL: #{e.message}"
    webflow_main_image_url
  end

  # Webflow status methods
  def published?
    !is_draft && !is_archived && webflow_item_id.present?
  end

  def draft?
    is_draft || webflow_item_id.blank?
  end

  def archived?
    is_archived
  end

  def mark_as_published!
    update!(
      is_draft: false,
      is_archived: false,
      last_published: Time.current
    )
  end

  def mark_as_draft!
    update!(
      is_draft: true,
      is_archived: false
    )
  end

  def mark_as_archived!
    update!(
      is_archived: true,
      is_draft: false
    )
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

  def subtotal
    calculate_subtotal
  end

  def vat_amount
    return 0 if total_vat_included_price.nil? || total_vat_excluded_price.nil?

    begin
      total_vat_included_price - total_vat_excluded_price
    rescue StandardError => e
      Rails.logger.error "Error calculating VAT amount: #{e.message}"
      0
    end
  end

  # Override WebflowSyncable method to include draft logic
  def should_auto_sync_to_webflow?
    # Only sync if it's a draft or has never been synced
    draft? && !deleted? && !skip_webflow_sync && webflow_collection_id.present?
  end

  # WebflowSyncable implementation
  def webflow_formatted_data
    to_webflow_formatted
  end

  def webflow_collection_id
    ENV.fetch('WEBFLOW_WRS_COLLECTION_ID', nil)
  end

  private

  def calculate_totals
    subtotal_amount = calculate_subtotal
    self.total_vat_excluded_price = subtotal_amount
    self.total_vat_included_price = (subtotal_amount * 1.2).round(2) # 20% VAT
    self.grand_total = total_vat_included_price
  rescue StandardError => e
    Rails.logger.error "Error calculating totals: #{e.message}"
    self.total_vat_excluded_price = 0
    self.total_vat_included_price = 0
    self.grand_total = 0
  end

  def calculate_subtotal
    subtotal = 0
    if windows.any?
      windows.each do |window|
        next unless window.tools.any?

        window.tools.each do |tool|
          subtotal += tool.price.to_f if tool.price
        end
      end
    end
    subtotal
  rescue StandardError => e
    Rails.logger.error "Error calculating subtotal: #{e.message}"
    0
  end

  def generate_slug
    return if slug.present?
    return if address.blank?
    return if flat_number.blank?

    self.slug = "#{address.parameterize}-#{flat_number.parameterize}-#{SecureRandom.hex(2)}"
  end

  def generate_reference_number
    return if reference_number.present?

    # Generate a user-friendly reference number: WRS-YYYYMMDD-###
    date_part = Time.current.strftime('%Y%m%d')

    # Find the highest sequence number for today
    today_wrs_count = WindowScheduleRepair.unscoped
                                          .where('reference_number LIKE ?', "WRS-#{date_part}-%")
                                          .count

    sequence = format('%03d', today_wrs_count + 1)
    self.reference_number = "WRS-#{date_part}-#{sequence}"
  end

  def set_default_webflow_flags
    self.is_draft = true if is_draft.nil?
    self.is_archived = false if is_archived.nil?
  end

  # Ransack configuration for filtering
  def self.ransackable_attributes(_auth_object = nil)
    %w[name slug flat_number reference_number address details status created_at updated_at total_vat_included_price
       total_vat_excluded_price grand_total deleted_at last_published is_draft is_archived]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user windows tools]
  end
end
