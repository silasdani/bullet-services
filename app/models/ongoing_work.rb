# frozen_string_literal: true

class OngoingWork < ApplicationRecord
  belongs_to :work_order, foreign_key: :work_order_id
  belongs_to :user
  has_many :time_entries, dependent: :nullify
  has_many_attached :images

  validates :work_date, presence: true
  validates :work_order_id, presence: true
  validates :user_id, presence: true
  validate :images_or_description?, unless: :is_draft?

  scope :for_wrs, ->(wrs_id) { where(work_order_id: wrs_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :recent, -> { order(work_date: :desc, created_at: :desc) }
  scope :with_images, -> { joins(:images_attachments) }
  scope :drafts, -> { where(is_draft: true) }
  scope :published, -> { where(is_draft: false) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[work_date work_order_id user_id created_at is_draft]
  end

  def publish!
    if time_entries.clocked_in.exists?
      errors.add(:base, 'Check out from your active session before completing this entry.')
      return false
    end
    update!(is_draft: false)
  end

  def draft?
    is_draft?
  end

  def total_hours
    time_entries.completed.sum { |te| te.duration_hours || 0 }
  end

  def active_session
    time_entries.clocked_in.first
  end

  def checked_in?
    time_entries.clocked_in.exists?
  end

  def image_urls
    return [] unless images.attached?

    images.map { |img| Rails.application.routes.url_helpers.rails_blob_path(img, only_path: true) }
  end

  # Used by Avo windows_info_field to render images grouped by work order windows
  def images_with_windows
    self
  end

  private

  def images_or_description?
    return true if images.attached? || description.present?

    errors.add(:base, 'Must have at least images or description')
    false
  end
end
