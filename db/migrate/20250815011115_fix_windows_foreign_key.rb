class FixWindowsForeignKey < ActiveRecord::Migration[8.0]
  def change
    # Remove the old foreign key constraint
    remove_foreign_key :windows, column: :window_schedule_repairs_id

    # Rename the column to match the model expectation
    rename_column :windows, :window_schedule_repairs_id, :window_schedule_repair_id

    # Add the new foreign key constraint
    add_foreign_key :windows, :window_schedule_repairs, column: :window_schedule_repair_id
  end
end
