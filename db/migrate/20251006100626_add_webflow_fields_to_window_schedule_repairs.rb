class AddWebflowFieldsToWindowScheduleRepairs < ActiveRecord::Migration[8.0]
  def change
    add_column :window_schedule_repairs, :last_published, :datetime
    add_column :window_schedule_repairs, :is_draft, :boolean
    add_column :window_schedule_repairs, :is_archived, :boolean
  end
end
