# frozen_string_literal: true

class Notification < ApplicationRecord
  include SoftDeletable

  belongs_to :user
  belongs_to :work_order, optional: true, foreign_key: :work_order_id

  validates :notification_type, presence: true
  validates :title, presence: true

  enum :notification_type, check_in: 0, check_out: 1, work_update: 2, system: 3, supervisor_wrs_created: 4

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }

  # read boolean removed - use read_at instead
  def read?
    read_at.present?
  end

  def unread?
    read_at.blank?
  end

  def mark_as_read!
    update!(read_at: Time.current)
  end

  def mark_as_unread!
    update!(read_at: nil)
  end
end
