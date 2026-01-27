class CreateOngoingWorks < ActiveRecord::Migration[8.0]
  def change
    create_table :ongoing_works do |t|
      t.references :window_schedule_repair, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :description
      t.datetime :work_date, null: false

      t.timestamps
    end

    add_index :ongoing_works, [:window_schedule_repair_id, :work_date]
  end
end
