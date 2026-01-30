class CreateCheckIns < ActiveRecord::Migration[8.0]
  def change
    create_table :check_ins do |t|
      t.references :user, null: false, foreign_key: true
      t.references :window_schedule_repair, null: false, foreign_key: true
      t.integer :action, null: false # 0 for check_in, 1 for check_out
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.string :address
      t.datetime :timestamp, null: false

      t.timestamps
    end

    add_index :check_ins, [:user_id, :window_schedule_repair_id, :action]
    add_index :check_ins, :timestamp
  end
end
