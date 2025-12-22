class AddIndexesToFrequentlyQueriedColumns < ActiveRecord::Migration[8.0]
  def change
    # Add index on window_schedule_repairs.slug (used for lookups)
    add_index :window_schedule_repairs, :slug, unique: true, if_not_exists: true

    # Add index on window_schedule_repairs.user_id (if not already exists from foreign key)
    # Note: add_reference usually adds this, but we ensure it exists
    add_index :window_schedule_repairs, :user_id, if_not_exists: true unless index_exists?(:window_schedule_repairs, :user_id)

    # Add index on window_schedule_repairs.building_id (if not already exists from foreign key)
    add_index :window_schedule_repairs, :building_id, if_not_exists: true unless index_exists?(:window_schedule_repairs, :building_id)

    # Add index on window_schedule_repairs.status (used for filtering)
    add_index :window_schedule_repairs, :status, if_not_exists: true unless index_exists?(:window_schedule_repairs, :status)

    # Add index on invoices.window_schedule_repair_id (if not already exists)
    add_index :invoices, :window_schedule_repair_id, if_not_exists: true unless index_exists?(:invoices, :window_schedule_repair_id)

    # Add index on invoices.slug (used for lookups)
    add_index :invoices, :slug, if_not_exists: true unless index_exists?(:invoices, :slug)
  end
end
