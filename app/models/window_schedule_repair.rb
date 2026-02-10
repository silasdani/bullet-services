# frozen_string_literal: true

class WindowScheduleRepair < ApplicationRecord
  include SoftDeletable
  include WrsCalculations
  include WrsGeneration
  include StatusMetadata

  # DB table has been renamed to `work_orders` (model name kept for compatibility).
  self.table_name = 'work_orders'

  belongs_to :user
  belongs_to :building
  has_many :windows, dependent: :destroy, foreign_key: :work_order_id
  has_many :tools, through: :windows
  has_many :invoices, dependent: :nullify, foreign_key: :work_order_id
  has_many :check_ins, dependent: :destroy, foreign_key: :work_order_id # Deprecated: Use work_sessions instead
  has_many :work_sessions, dependent: :destroy, foreign_key: :work_order_id
  has_many :ongoing_works, dependent: :destroy, foreign_key: :work_order_id
  has_many :notifications, dependent: :destroy, foreign_key: :work_order_id
  has_one :work_order_decision, dependent: :destroy, foreign_key: :work_order_id
  has_many :price_snapshots, dependent: :destroy, foreign_key: :work_order_id, inverse_of: :work_order
  has_many_attached :images

  accepts_nested_attributes_for :windows, allow_destroy: true, reject_if: :all_blank

  enum :status, pending: 0, approved: 1, rejected: 2, completed: 3

  validates :name, presence: true
  validates :building, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :for_user, lambda { |user|
    case user.role
    when 'admin'
      all
    when 'contractor', 'client'
      where(user: user)
    end
  }

  # Webflow-related scopes
  scope :published, -> { where(is_draft: false, is_archived: false) }
  scope :draft, -> { where(is_draft: true) }
  scope :archived, -> { where(is_archived: true) }

  # WRS visible to contractors: pending, approved, rejected (excludes completed).
  scope :contractor_visible_status, -> { where(status: statuses.values_at(:pending, :approved, :rejected)) }

  # Return first S3 image URL
  def main_image_url
    return nil unless images.attached? && images.first.present?

    images.first.url
  rescue StandardError => e
    Rails.logger.error "Error generating main image URL: #{e.message}"
    nil
  end

  # Publishing status methods (no longer Webflow-specific)
  def published?
    !is_draft && !is_archived
  end

  def draft?
    is_draft
  end

  def archived?
    is_archived
  end

  def mark_as_published!
    update!(
      is_draft: false,
      is_archived: false
    )
  end
  alias publish! mark_as_published!

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

  # Address from building (address column removed)
  def address
    building&.full_address || building&.address_string
  end

  # Decision helpers
  def decision
    work_order_decision&.decision
  end

  def decision_at
    work_order_decision&.decision_at
  end

  def approved?
    decision == 'approved'
  end

  def rejected?
    decision == 'rejected'
  end

  def has_decision?
    work_order_decision.present?
  end

  # Grand total alias for backwards compatibility (removed from DB)
  def grand_total
    total_vat_included_price || 0
  end

  # Ransack configuration for filtering
  def self.ransackable_attributes(_auth_object = nil)
    %w[name slug flat_number reference_number details status created_at updated_at total_vat_included_price
       total_vat_excluded_price deleted_at is_draft is_archived]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user windows tools building]
  end
end
