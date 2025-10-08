class WindowScheduleRepair < ApplicationRecord
  include Wrs

  belongs_to :user
  has_many :windows, dependent: :destroy
  has_many :tools, through: :windows
  has_many_attached :images

  # Return first S3 image URL if mirrored, otherwise fallback to Webflow URL stored
  def main_image_url
    if images.attached? && images.first.present?
      images.first.url
    else
      webflow_main_image_url
    end
  rescue => e
    Rails.logger.error "Error generating main image URL: #{e.message}"
    webflow_main_image_url
  end

  accepts_nested_attributes_for :windows, allow_destroy: true, reject_if: :all_blank

  # Soft delete functionality
  default_scope { where(deleted_at: nil) }
  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
  scope :with_deleted, -> { unscoped }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  def active?
    deleted_at.nil?
  end

  # Add safety for nested attributes
  def windows_attributes=(attributes)
    super(attributes.reject { |_, v| v.blank? })
  end

  enum :status, pending: 0, approved: 1, rejected: 2, completed: 3

  validates :name, presence: true
  validates :address, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create
  before_validation :set_default_webflow_flags, on: :create

  before_save :calculate_totals

  # Automatic Webflow synchronization
  # Only syncs draft items to protect published content
  after_commit :auto_sync_to_webflow, on: [ :create, :update ], if: :should_auto_sync_to_webflow?

  scope :for_user, ->(user) {
    case user.role
    when "admin"
      all
    when "employee"
      where(user: user)
    when "client"
      where(user: user)
    end
  }

  # Webflow-related scopes
  scope :published, -> { where(is_draft: false, is_archived: false) }
  scope :draft, -> { where(is_draft: true) }
  scope :archived, -> { where(is_archived: true) }

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
    when "pending"
      "#FFA500" # Orange for pending
    when "approved"
      "#00FF00" # Green for approved
    when "rejected"
      "#FF0000" # Red for rejected
    when "completed"
      "#0000FF" # Blue for completed
    else
      "#FFA500" # Default orange for pending
    end
  end


  def generate_slug
    return if slug.present?
    return if address.blank?
    return if flat_number.blank?

    self.slug = "#{address.parameterize}-#{flat_number.parameterize}-#{SecureRandom.hex(2)}"
  end

  def set_default_webflow_flags
    # Set default values for Webflow flags if not already set
    self.is_draft = true if is_draft.nil?
    self.is_archived = false if is_archived.nil?
  end

  private

  def should_auto_sync_to_webflow?
    # Auto-sync only if:
    # 1. Not deleted
    # 2. Is a draft OR has never been synced to Webflow
    # This prevents accidentally updating published items
    !deleted? && (is_draft? || webflow_item_id.blank?)
  end

  def auto_sync_to_webflow
    # Run sync in background to avoid blocking the main request
    AutoSyncToWebflowJob.perform_later(id)
  end

  # Ransack configuration for filtering
  def self.ransackable_attributes(auth_object = nil)
    %w[name slug flat_number reference_number address details status created_at updated_at total_vat_included_price total_vat_excluded_price grand_total deleted_at last_published is_draft is_archived]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[user windows tools]
  end
end
