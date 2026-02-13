# frozen_string_literal: true

class CreateStatusDefinitions < ActiveRecord::Migration[8.0]
  def change
    create_table :status_definitions do |t|
      t.string :entity_type, null: false # 'WindowScheduleRepair', 'Invoice', 'WorkOrder'
      t.string :status_key, null: false  # 'pending', 'approved', etc.
      t.string :status_label, null: false # 'Pending Approval', 'Approved', etc.
      t.string :status_color, null: false # '#FF5733', etc.
      t.integer :display_order, default: 0
      t.boolean :is_active, default: true, null: false
      
      t.timestamps
    end

    add_index :status_definitions, [:entity_type, :status_key], unique: true, name: 'index_status_definitions_on_entity_and_key'
    add_index :status_definitions, [:entity_type, :is_active, :display_order], name: 'index_status_definitions_on_entity_active_order'
  end
end
