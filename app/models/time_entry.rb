# frozen_string_literal: true

class TimeEntry < ApplicationRecord
  belongs_to :user
  belongs_to :work_order
  belongs_to :ongoing_work, optional: true

  before_validation :set_work_order_from_ongoing_work

  validates :starts_at, presence: true
  validate :ends_at_after_starts_at, if: -> { ends_at.present? }
  validate :no_overlapping_open_entry, on: :create

  scope :clocked_in, -> { where(ends_at: nil) }
  scope :completed, -> { where.not(ends_at: nil) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_work_order, ->(work_order) { where(work_order: work_order) }
  scope :for_ongoing_work, ->(ongoing_work) { where(ongoing_work: ongoing_work) }
  scope :recent, -> { order(starts_at: :desc) }

  scope :in_month, lambda { |year, month|
    start_at = Time.zone.local(year, month, 1)
    end_at = start_at.end_of_month + 1.second
    completed.where(ends_at: start_at...end_at)
  }

  def clocked_in?
    ends_at.nil?
  end

  def completed?
    ends_at.present?
  end

  def duration_minutes
    return nil unless completed?

    ((ends_at - starts_at) / 60).round(2)
  end

  def duration_hours
    return nil unless completed?

    ((ends_at - starts_at) / 3600).round(2)
  end

  def check_out!(ends_at_time: Time.current, latitude: nil, longitude: nil, address: nil, auto: false)
    update!(
      ends_at: ends_at_time,
      end_lat: latitude,
      end_lng: longitude,
      end_address: address,
      auto_checkout: auto
    )
  end

  private

  def set_work_order_from_ongoing_work
    return unless ongoing_work.present? && work_order_id.blank?

    self.work_order_id = ongoing_work.work_order_id
  end

  def ends_at_after_starts_at
    return unless ends_at && starts_at

    errors.add(:ends_at, 'must be after start time') if ends_at <= starts_at
  end

  def no_overlapping_open_entry
    return unless user && starts_at

    return unless open_entry_exists?

    errors.add(:base, 'You already have an active time entry. Please check out first.')
  end

  def open_entry_exists?
    TimeEntry
      .where(user: user)
      .where(ends_at: nil)
      .where.not(id: id || 0)
      .exists?
  end

  class << self
    private

    def ransackable_attributes(_auth_object = nil)
      %w[user_id work_order_id ongoing_work_id starts_at ends_at start_address end_address auto_checkout created_at updated_at]
    end

    def ransackable_associations(_auth_object = nil)
      %w[user work_order ongoing_work]
    end
  end
end
