# frozen_string_literal: true

class CheckIn < ApplicationRecord
  belongs_to :user
  belongs_to :window_schedule_repair

  enum action: { check_in: 0, check_out: 1 }

  validates :action, presence: true
  validates :timestamp, presence: true
  validates :user_id, presence: true
  validates :window_schedule_repair_id, presence: true

  scope :for_wrs, ->(wrs_id) { where(window_schedule_repair_id: wrs_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :check_ins, -> { where(action: :check_in) }
  scope :check_outs, -> { where(action: :check_out) }
  scope :recent, -> { order(timestamp: :desc) }

  # Find active check-ins (check-in without corresponding check-out)
  scope :active_for, lambda { |user, wrs|
    check_ins
      .where(user: user, window_schedule_repair: wrs)
      .where.not(id: check_outs.where(user: user, window_schedule_repair: wrs).select(:id))
  }
end
