# frozen_string_literal: true

class WindowScheduleRepair < ApplicationRecord
  include Wrs
  include SoftDeletable
  include WebflowSyncable
  include WrsCalculations
  include WrsGeneration

  belongs_to :user
  belongs_to :building
  has_many :windows, dependent: :destroy
  has_many :tools, through: :windows
  has_many :invoices, dependent: :nullify
  has_many :check_ins, dependent: :destroy
  has_many :ongoing_works, dependent: :destroy
  has_many :notifications, dependent: :destroy
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
    !is_draft && !is_archived && (webflow_item_id.present? || last_published.present?)
  end

  def draft?
    is_draft || (webflow_item_id.blank? && last_published.blank?)
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
  alias publish! mark_as_published!

  def mark_as_draft!
    update!(
      is_draft: true,
      is_archived: false,
      last_published: nil
    )
  end

  def mark_as_archived!
    update!(
      is_archived: true,
      is_draft: false,
      last_published: nil
    )
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

  # Backwards compatibility: return address string from building in Webflow format
  # Format: "{building.name}, {building.street}, {building.zipcode}"
  def address
    if building.present?
      # Format: building name, street, postcode
      parts = [building.name, building.street, building.zipcode].compact.reject(&:blank?)
      parts.join(', ')
    else
      begin
        read_attribute(:address)
      rescue StandardError
        nil
      end
    end
  end

  # Ransack configuration for filtering
  def self.ransackable_attributes(_auth_object = nil)
    %w[name slug flat_number reference_number address details status created_at updated_at total_vat_included_price
       total_vat_excluded_price grand_total deleted_at last_published is_draft is_archived]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user windows tools building]
  end
end
