# frozen_string_literal: true

class FixToolsPriceToDecimal < ActiveRecord::Migration[8.0]
  def up
    # Change price from integer to decimal for precision
    change_column :tools, :price, :decimal, precision: 10, scale: 2, null: false, default: 0.0
    
    # Add check constraint to ensure non-negative prices
    add_check_constraint :tools, "price >= 0", name: "tools_price_non_negative"
  end

  def down
    remove_check_constraint :tools, name: "tools_price_non_negative"
    change_column :tools, :price, :integer, null: false, default: 0
  end
end
