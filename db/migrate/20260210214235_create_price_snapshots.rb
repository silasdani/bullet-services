# frozen_string_literal: true

class CreatePriceSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :price_snapshots do |t|
      t.references :priceable, polymorphic: true, null: false, index: true
      t.decimal :subtotal, precision: 10, scale: 2
      t.decimal :vat_rate, precision: 5, scale: 4
      t.decimal :vat_amount, precision: 10, scale: 2
      t.decimal :total, precision: 10, scale: 2
      t.datetime :snapshot_at, null: false
      t.jsonb :line_items # Store tool prices at time of snapshot
      
      t.timestamps
    end

    add_index :price_snapshots, [:priceable_type, :priceable_id, :snapshot_at], 
              name: 'index_price_snapshots_on_priceable_and_time'
    add_index :price_snapshots, :snapshot_at
  end
end
