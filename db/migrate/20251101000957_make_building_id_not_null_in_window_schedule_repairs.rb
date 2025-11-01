class MakeBuildingIdNotNullInWindowScheduleRepairs < ActiveRecord::Migration[8.0]
  def up
    # Ensure all WRS have a building_id before making it NOT NULL
    # This should have been handled by the data migration, but double-check
    execute <<-SQL
      UPDATE window_schedule_repairs
      SET building_id = (SELECT id FROM buildings LIMIT 1)
      WHERE building_id IS NULL;
    SQL

    # Now make it NOT NULL
    change_column_null :window_schedule_repairs, :building_id, false
  end

  def down
    change_column_null :window_schedule_repairs, :building_id, true
  end
end
