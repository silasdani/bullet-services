# frozen_string_literal: true

class CheckIn < ApplicationRecord
  belongs_to :user
  belongs_to :window_schedule_repair, class_name: 'WindowScheduleRepair', foreign_key: :work_order_id

  enum :action, check_in: 0, check_out: 1

  validates :action, presence: true
  validates :timestamp, presence: true
  validates :user_id, presence: true
  validates :work_order_id, presence: true

  scope :for_wrs, ->(wrs_id) { where(work_order_id: wrs_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :check_ins, -> { where(action: :check_in) }
  scope :check_outs, -> { where(action: :check_out) }
  scope :recent, -> { order(timestamp: :desc) }

  # Active = check-in row with no later check-out for same (user, wrs).
  scope :active_for, lambda { |user, wrs = nil|
    base = check_ins.where(user: user)
    base = base.where(window_schedule_repair: wrs) if wrs.present?

    base.where(
      <<~SQL.squish,
        NOT EXISTS (
          SELECT 1 FROM check_ins AS ci2
          WHERE ci2.user_id = check_ins.user_id
          AND ci2.work_order_id = check_ins.work_order_id
          AND ci2.action = ?
          AND ci2.id > check_ins.id
        )
      SQL
      actions['check_out']
    )
  }

  def self.ransackable_attributes(_auth_object = nil)
    %w[action timestamp latitude longitude address user_id work_order_id created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user window_schedule_repair]
  end
end
