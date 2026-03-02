class AddUniqueIndexToOngoingWorksOnWorkOrderId < ActiveRecord::Migration[8.0]
  def change
    # Replace existing non-unique index (from the original t.references) with a unique one.
    remove_index :ongoing_works, :work_order_id if index_exists?(:ongoing_works, :work_order_id)
    add_index :ongoing_works, :work_order_id, unique: true
  end
end

