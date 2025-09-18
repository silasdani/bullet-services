class AddDeletedAtToWindowScheduleRepairs < ActiveRecord::Migration[8.0]
  def change
    add_column :window_schedule_repairs, :deleted_at, :datetime
    add_index :window_schedule_repairs, :deleted_at
  end
end
