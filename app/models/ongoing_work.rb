# frozen_string_literal: true

class OngoingWork < ApplicationRecord
  belongs_to :work_order, foreign_key: :work_order_id
  belongs_to :user
  has_many :work_sessions, dependent: :destroy
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
    update!(is_draft: false)
  end

  def draft?
    is_draft?
  end

  def total_hours
    work_sessions.completed.sum { |ws| ws.duration_hours || 0 }
  end

  def active_session
    work_sessions.active.first
  end

  def checked_in?
    work_sessions.active.exists?
  end

  def image_urls
    return [] unless images.attached?

    images.map { |img| Rails.application.routes.url_helpers.rails_blob_path(img, only_path: true) }
  end

  private

  def images_or_description?
    return true if images.attached? || description.present?

    errors.add(:base, 'Must have at least images or description')
    false
  end
end
