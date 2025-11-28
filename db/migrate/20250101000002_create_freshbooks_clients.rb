# frozen_string_literal: true

class CreateFreshbooksClients < ActiveRecord::Migration[8.0]
  def change
    create_table :freshbooks_clients do |t|
      t.string :freshbooks_id, null: false
      t.string :email
      t.string :first_name
      t.string :last_name
      t.string :organization
      t.string :phone
      t.text :address
      t.string :city
      t.string :province
      t.string :postal_code
      t.string :country
      t.jsonb :raw_data

      t.timestamps
    end

    add_index :freshbooks_clients, :freshbooks_id, unique: true
    add_index :freshbooks_clients, :email
  end
end
