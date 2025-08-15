class CreateWindowsTable < ActiveRecord::Migration[8.0]
  def change
    create_table :windows do |t|
      t.string :image
      t.string :location
      t.references :window_schedule_repairs, null: false, foreign_key: true

      t.timestamps
    end
  end
end
