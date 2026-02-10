# frozen_string_literal: true

class AddSoftDeletesToAllTables < ActiveRecord::Migration[8.0]
  def change
    # Add deleted_at to tables that don't have it
    add_column :windows, :deleted_at, :datetime unless column_exists?(:windows, :deleted_at)
    add_column :tools, :deleted_at, :datetime unless column_exists?(:tools, :deleted_at)
    add_column :check_ins, :deleted_at, :datetime unless column_exists?(:check_ins, :deleted_at)
    add_column :ongoing_works, :deleted_at, :datetime unless column_exists?(:ongoing_works, :deleted_at)
    add_column :invoices, :deleted_at, :datetime unless column_exists?(:invoices, :deleted_at)
    add_column :work_sessions, :deleted_at, :datetime unless column_exists?(:work_sessions, :deleted_at)
    add_column :work_order_decisions, :deleted_at, :datetime unless column_exists?(:work_order_decisions, :deleted_at)
    add_column :price_snapshots, :deleted_at, :datetime unless column_exists?(:price_snapshots, :deleted_at)

    # Add indexes for soft delete queries
    add_index :windows, :deleted_at unless index_exists?(:windows, :deleted_at)
    add_index :tools, :deleted_at unless index_exists?(:tools, :deleted_at)
    add_index :check_ins, :deleted_at unless index_exists?(:check_ins, :deleted_at)
    add_index :ongoing_works, :deleted_at unless index_exists?(:ongoing_works, :deleted_at)
    add_index :invoices, :deleted_at unless index_exists?(:invoices, :deleted_at)
    add_index :work_sessions, :deleted_at unless index_exists?(:work_sessions, :deleted_at)
    add_index :work_order_decisions, :deleted_at unless index_exists?(:work_order_decisions, :deleted_at)
    add_index :price_snapshots, :deleted_at unless index_exists?(:price_snapshots, :deleted_at)
  end
end
