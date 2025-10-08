class ChangeToolsPriceToInteger < ActiveRecord::Migration[8.0]
  def up
    change_column :tools, :price, :integer
  end

  def down
    change_column :tools, :price, :decimal, precision: 10, scale: 2
  end
end
