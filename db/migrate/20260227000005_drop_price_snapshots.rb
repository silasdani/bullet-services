# frozen_string_literal: true

class DropPriceSnapshots < ActiveRecord::Migration[8.0]
  def up
    drop_table :price_snapshots, if_exists: true
  end

  def down
    create_table :price_snapshots do |t|
      t.string :priceable_type, null: false
      t.bigint :work_order_id, null: false
      t.decimal :subtotal, precision: 12, scale: 2
      t.decimal :vat_rate, precision: 5, scale: 4
      t.decimal :vat_amount, precision: 12, scale: 2
      t.decimal :total, precision: 12, scale: 2
      t.datetime :snapshot_at, null: false
      t.jsonb :line_items
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :price_snapshots, %i[priceable_type work_order_id snapshot_at], name: 'index_price_snapshots_on_priceable_and_time'
    add_index :price_snapshots, :snapshot_at
    add_index :price_snapshots, :deleted_at
    add_foreign_key :price_snapshots, :work_orders
  end
end
