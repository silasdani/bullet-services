# frozen_string_literal: true

class WorkSession < ApplicationRecord
  include SoftDeletable

  # Determine foreign key column name (handles rename migration)
  def self.work_order_foreign_key
    @work_order_foreign_key ||= if connection.column_exists?(:work_sessions, :work_order_id)
                                  :work_order_id
                                else
                                  :window_schedule_repair_id
                                end
  end

  belongs_to :user
  belongs_to :work_order, class_name: 'WindowScheduleRepair',
                          foreign_key: work_order_foreign_key

  validates :checked_in_at, presence: true
  validate :checked_out_after_check_in, if: -> { checked_out_at.present? }
  validate :no_overlapping_sessions, on: :create

  scope :active, -> { where(checked_out_at: nil) }
  scope :completed, -> { where.not(checked_out_at: nil) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_work_order, ->(work_order) { where(work_order: work_order) }
  scope :recent, -> { order(checked_in_at: :desc) }

  def active?
    checked_out_at.nil?
  end

  def completed?
    checked_out_at.present?
  end

  def duration_minutes
    return nil unless completed?

    ((checked_out_at - checked_in_at) / 60).round(2)
  end

  def duration_hours
    return nil unless completed?

    ((checked_out_at - checked_in_at) / 3600).round(2)
  end

  def check_out!(checked_out_time: Time.current, latitude: nil, longitude: nil, address: nil)
    update!(
      checked_out_at: checked_out_time,
      latitude: latitude,
      longitude: longitude,
      address: address
    )
  end

  private

  def checked_out_after_check_in
    return unless checked_out_at && checked_in_at

    errors.add(:checked_out_at, 'must be after check-in time') if checked_out_at < checked_in_at
  end

  def no_overlapping_sessions
    return unless user && work_order && checked_in_at

    work_order_id_value = send(self.class.work_order_foreign_key)
    return unless work_order_id_value

    overlapping = WorkSession
                  .where(user: user)
                  .where(self.class.work_order_foreign_key => work_order_id_value)
                  .where('checked_out_at IS NULL OR checked_out_at > ?', checked_in_at)
                  .where('checked_in_at < ?', checked_in_at)
                  .where.not(id: id || 0)
                  .exists?

    errors.add(:base, 'Cannot create overlapping work session') if overlapping
  end
end
