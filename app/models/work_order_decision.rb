# frozen_string_literal: true

class WorkOrderDecision < ApplicationRecord
  include SoftDeletable

  belongs_to :work_order, foreign_key: :work_order_id

  validates :decision, presence: true, inclusion: { in: %w[approved rejected] }
  validates :decision_at, presence: true
  validates :work_order_id, uniqueness: true

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
