# frozen_string_literal: true

class CreateWorkOrderDecisions < ActiveRecord::Migration[8.0]
  def change
    create_table :work_order_decisions do |t|
      t.references :window_schedule_repair, null: false, foreign_key: true, index: { unique: true }
      t.string :decision, null: false # 'approved', 'rejected'
      t.datetime :decision_at, null: false
      t.string :client_email
      t.string :client_name
      t.datetime :terms_accepted_at
      t.string :terms_version
      t.jsonb :decision_metadata
      
      t.timestamps
    end

    add_index :work_order_decisions, :decision_at
  end
end
