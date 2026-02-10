# frozen_string_literal: true

class CreateWorkSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :work_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :window_schedule_repair, null: false, foreign_key: true
      t.datetime :checked_in_at, null: false
      t.datetime :checked_out_at
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.string :address
      
      t.timestamps
    end

    add_index :work_sessions, [:user_id, :window_schedule_repair_id, :checked_out_at],
              name: 'index_work_sessions_on_user_wrs_checked_out'
    add_index :work_sessions, [:window_schedule_repair_id, :checked_in_at]
    add_index :work_sessions, :checked_in_at
  end
end
