# frozen_string_literal: true

class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Composite indexes for window_schedule_repairs
    add_index :window_schedule_repairs, [:building_id, :status, :deleted_at],
              name: 'index_wrs_on_building_status_deleted' unless index_exists?(:window_schedule_repairs, [:building_id, :status, :deleted_at])
    
    add_index :window_schedule_repairs, [:user_id, :status, :created_at],
              name: 'index_wrs_on_user_status_created' unless index_exists?(:window_schedule_repairs, [:user_id, :status, :created_at])

    # Partial index for active WRS (most common query)
    add_index :window_schedule_repairs, [:status],
              where: "deleted_at IS NULL AND is_draft = false",
              name: 'index_wrs_on_status_active' unless index_exists?(:window_schedule_repairs, [:status], name: 'index_wrs_on_status_active')

    # Composite indexes for check_ins (if still using)
    add_index :check_ins, [:window_schedule_repair_id, :action, :timestamp],
              name: 'index_check_ins_on_wrs_action_timestamp' unless index_exists?(:check_ins, [:window_schedule_repair_id, :action, :timestamp])

    # Composite indexes for notifications
    add_index :notifications, [:user_id, :read_at, :created_at],
              name: 'index_notifications_on_user_read_created' unless index_exists?(:notifications, [:user_id, :read_at, :created_at])
    
    add_index :notifications, [:window_schedule_repair_id, :notification_type],
              name: 'index_notifications_on_wrs_type' unless index_exists?(:notifications, [:window_schedule_repair_id, :notification_type])

    # Partial index for unread notifications
    add_index :notifications, [:user_id, :created_at],
              where: "read_at IS NULL",
              name: 'index_notifications_on_user_unread' unless index_exists?(:notifications, [:user_id, :created_at], name: 'index_notifications_on_user_unread')

    # Composite indexes for ongoing_works
    add_index :ongoing_works, [:window_schedule_repair_id, :work_date, :user_id],
              name: 'index_ongoing_works_on_wrs_date_user' unless index_exists?(:ongoing_works, [:window_schedule_repair_id, :work_date, :user_id])

    # Composite indexes for work_sessions
    add_index :work_sessions, [:window_schedule_repair_id, :checked_in_at],
              name: 'index_work_sessions_on_wrs_checked_in' unless index_exists?(:work_sessions, [:window_schedule_repair_id, :checked_in_at])
  end
end
