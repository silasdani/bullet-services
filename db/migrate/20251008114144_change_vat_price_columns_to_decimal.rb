class ChangeVatPriceColumnsToDecimal < ActiveRecord::Migration[8.0]
  def up
    change_column :window_schedule_repairs, :total_vat_included_price, :decimal, precision: 10, scale: 2
    change_column :window_schedule_repairs, :total_vat_excluded_price, :decimal, precision: 10, scale: 2
    change_column :tools, :price, :decimal, precision: 10, scale: 2
  end

  def down
    change_column :window_schedule_repairs, :total_vat_included_price, :integer
    change_column :window_schedule_repairs, :total_vat_excluded_price, :integer
    change_column :tools, :price, :integer
  end
end
