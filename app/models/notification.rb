# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :window_schedule_repair, optional: true

  validates :notification_type, presence: true
  validates :title, presence: true

  enum :notification_type, check_in: 0, check_out: 1, work_update: 2, system: 3

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }

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
