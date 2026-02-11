# frozen_string_literal: true

class WorkOrderAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :work_order, class_name: 'WindowScheduleRepair', foreign_key: :work_order_id
  belongs_to :assigned_by_user, class_name: 'User', optional: true

  validates :user_id, presence: true
  validates :work_order_id, presence: true
  validates :work_order_id, uniqueness: { scope: :user_id }
end
