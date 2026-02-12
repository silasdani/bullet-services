# frozen_string_literal: true

class AddWorkTypeToWorkOrders < ActiveRecord::Migration[8.0]
  def up
    # work_type: 0 = wrs (window schedule repair), 1 = general (general work)
    add_column :work_orders, :work_type, :integer, default: 0, null: false
    add_index :work_orders, :work_type, name: 'index_work_orders_on_work_type'
  end

  def down
    remove_index :work_orders, name: 'index_work_orders_on_work_type', if_exists: true
    remove_column :work_orders, :work_type, :integer
  end
end
