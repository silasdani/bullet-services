class AddMissingColumnsToWindowScheduleRepairs < ActiveRecord::Migration[8.0]
  def change
    # Add missing columns
    add_reference :window_schedule_repairs, :user, null: false, foreign_key: true

    # Rename columns to match model expectations
    rename_column :window_schedule_repairs, :total_included_vat, :total_vat_included_price
    rename_column :window_schedule_repairs, :total_excluded_vat, :total_vat_excluded_price

    # Add missing columns that the model expects
    add_column :window_schedule_repairs, :details, :text
    add_column :window_schedule_repairs, :grand_total, :decimal, precision: 10, scale: 2
  end
end
