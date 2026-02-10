# frozen_string_literal: true

class RenameWindowScheduleRepairsToWorkOrders < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Rename the main table
    rename_table :window_schedule_repairs, :work_orders

    # Step 2: Rename all foreign key columns
    rename_column :windows, :window_schedule_repair_id, :work_order_id
    rename_column :check_ins, :window_schedule_repair_id, :work_order_id
    rename_column :invoices, :window_schedule_repair_id, :work_order_id
    rename_column :notifications, :window_schedule_repair_id, :work_order_id
    rename_column :ongoing_works, :window_schedule_repair_id, :work_order_id
    rename_column :work_order_decisions, :window_schedule_repair_id, :work_order_id
    rename_column :work_sessions, :window_schedule_repair_id, :work_order_id
    rename_column :price_snapshots, :priceable_id, :work_order_id if column_exists?(:price_snapshots, :priceable_id)

    # Step 3: Drop old foreign key constraints
    remove_foreign_key :windows, :window_schedule_repairs if foreign_key_exists?(:windows, :window_schedule_repairs)
    remove_foreign_key :check_ins, :window_schedule_repairs if foreign_key_exists?(:check_ins, :window_schedule_repairs)
    remove_foreign_key :invoices, :window_schedule_repairs if foreign_key_exists?(:invoices, :window_schedule_repairs)
    remove_foreign_key :notifications, :window_schedule_repairs if foreign_key_exists?(:notifications, :window_schedule_repairs)
    remove_foreign_key :ongoing_works, :window_schedule_repairs if foreign_key_exists?(:ongoing_works, :window_schedule_repairs)
    remove_foreign_key :work_order_decisions, :window_schedule_repairs if foreign_key_exists?(:work_order_decisions, :window_schedule_repairs)
    remove_foreign_key :work_sessions, :window_schedule_repairs if foreign_key_exists?(:work_sessions, :window_schedule_repairs)
    remove_foreign_key :work_orders, :buildings if foreign_key_exists?(:work_orders, :buildings)
    remove_foreign_key :work_orders, :users if foreign_key_exists?(:work_orders, :users)

    # Step 4: Rename indexes
    rename_index :work_orders, 'index_window_schedule_repairs_on_building_id', 'index_work_orders_on_building_id' if index_exists?(:work_orders, :building_id, name: 'index_window_schedule_repairs_on_building_id')
    rename_index :work_orders, 'index_window_schedule_repairs_on_deleted_at', 'index_work_orders_on_deleted_at' if index_exists?(:work_orders, :deleted_at, name: 'index_window_schedule_repairs_on_deleted_at')
    rename_index :work_orders, 'index_window_schedule_repairs_on_slug', 'index_work_orders_on_slug' if index_exists?(:work_orders, :slug, name: 'index_window_schedule_repairs_on_slug')
    rename_index :work_orders, 'index_window_schedule_repairs_on_status', 'index_work_orders_on_status' if index_exists?(:work_orders, :status, name: 'index_window_schedule_repairs_on_status')
    rename_index :work_orders, 'index_window_schedule_repairs_on_user_id', 'index_work_orders_on_user_id' if index_exists?(:work_orders, :user_id, name: 'index_window_schedule_repairs_on_user_id')

    rename_index :windows, 'index_windows_on_window_schedule_repair_id', 'index_windows_on_work_order_id' if index_exists?(:windows, :window_schedule_repair_id, name: 'index_windows_on_window_schedule_repair_id')
    rename_index :check_ins, 'index_check_ins_on_window_schedule_repair_id', 'index_check_ins_on_work_order_id' if index_exists?(:check_ins, :window_schedule_repair_id, name: 'index_check_ins_on_window_schedule_repair_id')
    rename_index :invoices, 'index_invoices_on_window_schedule_repair_id', 'index_invoices_on_work_order_id' if index_exists?(:invoices, :window_schedule_repair_id, name: 'index_invoices_on_window_schedule_repair_id')
    rename_index :notifications, 'index_notifications_on_window_schedule_repair_id', 'index_notifications_on_work_order_id' if index_exists?(:notifications, :window_schedule_repair_id, name: 'index_notifications_on_window_schedule_repair_id')
    rename_index :ongoing_works, 'index_ongoing_works_on_window_schedule_repair_id', 'index_ongoing_works_on_work_order_id' if index_exists?(:ongoing_works, :window_schedule_repair_id, name: 'index_ongoing_works_on_window_schedule_repair_id')
    rename_index :ongoing_works, 'index_ongoing_works_on_window_schedule_repair_id_and_work_date', 'index_ongoing_works_on_work_order_id_and_work_date' if index_exists?(:ongoing_works, [:window_schedule_repair_id, :work_date], name: 'index_ongoing_works_on_window_schedule_repair_id_and_work_date')

    # Rename composite index for check_ins
    if index_exists?(:check_ins, [:user_id, :window_schedule_repair_id, :action], name: 'idx_on_user_id_window_schedule_repair_id_action_697816377c')
      remove_index :check_ins, name: 'idx_on_user_id_window_schedule_repair_id_action_697816377c'
      add_index :check_ins, [:user_id, :work_order_id, :action], name: 'idx_on_user_id_work_order_id_action_697816377c'
    end

    # Step 5: Add new foreign key constraints
    add_foreign_key :windows, :work_orders
    add_foreign_key :check_ins, :work_orders
    add_foreign_key :invoices, :work_orders
    add_foreign_key :notifications, :work_orders
    add_foreign_key :ongoing_works, :work_orders
    add_foreign_key :work_order_decisions, :work_orders
    add_foreign_key :work_sessions, :work_orders
    add_foreign_key :work_orders, :buildings
    add_foreign_key :work_orders, :users
  end

  def down
    # Reverse all changes
    remove_foreign_key :windows, :work_orders if foreign_key_exists?(:windows, :work_orders)
    remove_foreign_key :check_ins, :work_orders if foreign_key_exists?(:check_ins, :work_orders)
    remove_foreign_key :invoices, :work_orders if foreign_key_exists?(:invoices, :work_orders)
    remove_foreign_key :notifications, :work_orders if foreign_key_exists?(:notifications, :work_orders)
    remove_foreign_key :ongoing_works, :work_orders if foreign_key_exists?(:ongoing_works, :work_orders)
    remove_foreign_key :work_order_decisions, :work_orders if foreign_key_exists?(:work_order_decisions, :work_orders)
    remove_foreign_key :work_sessions, :work_orders if foreign_key_exists?(:work_sessions, :work_orders)
    remove_foreign_key :work_orders, :buildings if foreign_key_exists?(:work_orders, :buildings)
    remove_foreign_key :work_orders, :users if foreign_key_exists?(:work_orders, :users)

    rename_index :work_orders, 'index_work_orders_on_building_id', 'index_window_schedule_repairs_on_building_id' if index_exists?(:work_orders, :building_id, name: 'index_work_orders_on_building_id')
    rename_index :work_orders, 'index_work_orders_on_deleted_at', 'index_window_schedule_repairs_on_deleted_at' if index_exists?(:work_orders, :deleted_at, name: 'index_work_orders_on_deleted_at')
    rename_index :work_orders, 'index_work_orders_on_slug', 'index_window_schedule_repairs_on_slug' if index_exists?(:work_orders, :slug, name: 'index_work_orders_on_slug')
    rename_index :work_orders, 'index_work_orders_on_status', 'index_window_schedule_repairs_on_status' if index_exists?(:work_orders, :status, name: 'index_work_orders_on_status')
    rename_index :work_orders, 'index_work_orders_on_user_id', 'index_window_schedule_repairs_on_user_id' if index_exists?(:work_orders, :user_id, name: 'index_work_orders_on_user_id')

    rename_index :windows, 'index_windows_on_work_order_id', 'index_windows_on_window_schedule_repair_id' if index_exists?(:windows, :work_order_id, name: 'index_windows_on_work_order_id')
    rename_index :check_ins, 'index_check_ins_on_work_order_id', 'index_check_ins_on_window_schedule_repair_id' if index_exists?(:check_ins, :work_order_id, name: 'index_check_ins_on_work_order_id')
    rename_index :invoices, 'index_invoices_on_work_order_id', 'index_invoices_on_window_schedule_repair_id' if index_exists?(:invoices, :work_order_id, name: 'index_invoices_on_work_order_id')
    rename_index :notifications, 'index_notifications_on_work_order_id', 'index_notifications_on_window_schedule_repair_id' if index_exists?(:notifications, :work_order_id, name: 'index_notifications_on_work_order_id')
    rename_index :ongoing_works, 'index_ongoing_works_on_work_order_id', 'index_ongoing_works_on_window_schedule_repair_id' if index_exists?(:ongoing_works, :work_order_id, name: 'index_ongoing_works_on_work_order_id')
    rename_index :ongoing_works, 'index_ongoing_works_on_work_order_id_and_work_date', 'index_ongoing_works_on_window_schedule_repair_id_and_work_date' if index_exists?(:ongoing_works, [:work_order_id, :work_date], name: 'index_ongoing_works_on_work_order_id_and_work_date')

    if index_exists?(:check_ins, [:user_id, :work_order_id, :action], name: 'idx_on_user_id_work_order_id_action_697816377c')
      remove_index :check_ins, name: 'idx_on_user_id_work_order_id_action_697816377c'
      add_index :check_ins, [:user_id, :window_schedule_repair_id, :action], name: 'idx_on_user_id_window_schedule_repair_id_action_697816377c'
    end

    rename_column :windows, :work_order_id, :window_schedule_repair_id
    rename_column :check_ins, :work_order_id, :window_schedule_repair_id
    rename_column :invoices, :work_order_id, :window_schedule_repair_id
    rename_column :notifications, :work_order_id, :window_schedule_repair_id
    rename_column :ongoing_works, :work_order_id, :window_schedule_repair_id
    rename_column :work_order_decisions, :work_order_id, :window_schedule_repair_id
    rename_column :work_sessions, :work_order_id, :window_schedule_repair_id

    rename_table :work_orders, :window_schedule_repairs

    add_foreign_key :windows, :window_schedule_repairs
    add_foreign_key :check_ins, :window_schedule_repairs
    add_foreign_key :invoices, :window_schedule_repairs
    add_foreign_key :notifications, :window_schedule_repairs
    add_foreign_key :ongoing_works, :window_schedule_repairs
    add_foreign_key :work_order_decisions, :window_schedule_repairs
    add_foreign_key :work_sessions, :window_schedule_repairs
    add_foreign_key :window_schedule_repairs, :buildings
    add_foreign_key :window_schedule_repairs, :users
  end
end
