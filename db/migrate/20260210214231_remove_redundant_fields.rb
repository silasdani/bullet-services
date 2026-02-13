# frozen_string_literal: true

class RemoveRedundantFields < ActiveRecord::Migration[8.0]
  def up
    # Remove grand_total (redundant with total_vat_included_price)
    remove_column :window_schedule_repairs, :grand_total, :decimal
    
    # Remove read boolean (redundant with read_at timestamp)
    remove_column :notifications, :read, :boolean
    
    # Remove address from WRS (duplicates building address)
    remove_column :window_schedule_repairs, :address, :string
  end

  def down
    add_column :window_schedule_repairs, :grand_total, :decimal, precision: 10, scale: 2
    add_column :notifications, :read, :boolean, default: false, null: false
    add_column :window_schedule_repairs, :address, :string
  end
end
