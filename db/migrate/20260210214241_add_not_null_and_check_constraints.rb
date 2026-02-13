# frozen_string_literal: true

class AddNotNullAndCheckConstraints < ActiveRecord::Migration[8.0]
  def change
    # Add NOT NULL constraints
    change_column_null :window_schedule_repairs, :name, false
    change_column_null :window_schedule_repairs, :building_id, false
    change_column_null :window_schedule_repairs, :user_id, false
    change_column_null :windows, :location, false
    change_column_null :tools, :name, false

    # Add CHECK constraints for prices
    add_check_constraint :window_schedule_repairs, "total_vat_included_price >= 0",
                        name: "wrs_total_vat_included_non_negative" unless check_constraint_exists?(:window_schedule_repairs, name: "wrs_total_vat_included_non_negative")
    
    add_check_constraint :window_schedule_repairs, "total_vat_excluded_price >= 0",
                        name: "wrs_total_vat_excluded_non_negative" unless check_constraint_exists?(:window_schedule_repairs, name: "wrs_total_vat_excluded_non_negative")

    add_check_constraint :invoices, "included_vat_amount >= 0",
                        name: "invoices_included_vat_non_negative" unless check_constraint_exists?(:invoices, name: "invoices_included_vat_non_negative")
    
    add_check_constraint :invoices, "excluded_vat_amount >= 0",
                        name: "invoices_excluded_vat_non_negative" unless check_constraint_exists?(:invoices, name: "invoices_excluded_vat_non_negative")
  end
end
