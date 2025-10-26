class RemoveWebflowCollectionIdFromWindowScheduleRepairs < ActiveRecord::Migration[8.0]
  def change
    remove_column :window_schedule_repairs, :webflow_collection_id, :string
  end
end
