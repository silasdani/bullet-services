class CreateBuildings < ActiveRecord::Migration[8.0]
  def change
    create_table :buildings do |t|
      t.string :name
      t.string :street
      t.string :city
      t.string :country
      t.string :zipcode

      t.timestamps
      t.datetime :deleted_at

      t.index :deleted_at
      t.index :name
      t.index [:street, :city, :zipcode], name: 'index_buildings_on_address_fields'
    end
  end
end
