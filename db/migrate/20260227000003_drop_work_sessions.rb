# frozen_string_literal: true

class DropWorkSessions < ActiveRecord::Migration[8.0]
  def up
    drop_table :work_sessions, if_exists: true
  end

  def down
    create_table :work_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :work_order, null: false, foreign_key: true
      t.datetime :checked_in_at, null: false
      t.datetime :checked_out_at
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.string :address
      t.references :ongoing_work, null: true, foreign_key: true
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :work_sessions, %i[user_id work_order_id checked_out_at], name: 'index_work_sessions_on_user_wrs_checked_out'
    add_index :work_sessions, %i[work_order_id checked_in_at], name: 'index_work_sessions_on_work_order_id_and_checked_in_at'
    add_index :work_sessions, :checked_in_at
    add_index :work_sessions, :deleted_at
  end
end
