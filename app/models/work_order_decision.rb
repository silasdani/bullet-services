# frozen_string_literal: true

class WorkOrderDecision < ApplicationRecord
  include SoftDeletable

  # Determine foreign key column name (handles rename migration)
  def self.work_order_foreign_key
    @work_order_foreign_key ||= if connection.column_exists?(:work_order_decisions, :work_order_id)
                                  :work_order_id
                                else
                                  :window_schedule_repair_id
                                end
  end

  belongs_to :work_order, class_name: 'WindowScheduleRepair',
                          foreign_key: work_order_foreign_key

  validates :decision, presence: true, inclusion: { in: %w[approved rejected] }
  validates :decision_at, presence: true

  # Validate uniqueness - handle both column names
  validate :unique_work_order_decision

  private

  def unique_work_order_decision
    work_order_id_value = send(self.class.work_order_foreign_key)
    return unless work_order_id_value

    existing = self.class.where.not(id: id || 0)
                   .where(self.class.work_order_foreign_key => work_order_id_value)
                   .exists?

    errors.add(:base, 'Decision already exists for this work order') if existing
  end

  scope :approved, -> { where(decision: 'approved') }
  scope :rejected, -> { where(decision: 'rejected') }
  scope :recent, -> { order(decision_at: :desc) }

  def approved?
    decision == 'approved'
  end

  def rejected?
    decision == 'rejected'
  end
end
