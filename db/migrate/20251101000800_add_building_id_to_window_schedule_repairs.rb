class AddBuildingIdToWindowScheduleRepairs < ActiveRecord::Migration[8.0]
  def change
    # Add building_id as nullable first to allow data migration
    add_reference :window_schedule_repairs, :building, null: true, foreign_key: true
  end
end
