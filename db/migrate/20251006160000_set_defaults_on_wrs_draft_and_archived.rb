class SetDefaultsOnWrsDraftAndArchived < ActiveRecord::Migration[7.1]
  def up
    # Backfill NULLs to false
    execute <<~SQL
      UPDATE window_schedule_repairs SET is_draft = FALSE WHERE is_draft IS NULL;
    SQL
    execute <<~SQL
      UPDATE window_schedule_repairs SET is_archived = FALSE WHERE is_archived IS NULL;
    SQL

    # Set defaults
    change_column_default :window_schedule_repairs, :is_draft, from: nil, to: false
    change_column_default :window_schedule_repairs, :is_archived, from: nil, to: false

    # Enforce NOT NULL
    change_column_null :window_schedule_repairs, :is_draft, false
    change_column_null :window_schedule_repairs, :is_archived, false
  end

  def down
    # Allow NULLs again
    change_column_null :window_schedule_repairs, :is_draft, true
    change_column_null :window_schedule_repairs, :is_archived, true

    # Remove defaults
    change_column_default :window_schedule_repairs, :is_draft, from: false, to: nil
    change_column_default :window_schedule_repairs, :is_archived, from: false, to: nil
  end
end
