class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :window_schedule_repair, null: true, foreign_key: true
      t.integer :notification_type, null: false # 0: check_in, 1: check_out, 2: work_update, 3: system
      t.string :title, null: false
      t.text :message
      t.boolean :read, default: false, null: false
      t.jsonb :metadata # for storing additional data

      t.timestamps
    end

    add_index :notifications, [:user_id, :read]
    add_index :notifications, :created_at
  end
end
