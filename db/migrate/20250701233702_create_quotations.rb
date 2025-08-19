class CreateQuotations < ActiveRecord::Migration[8.0]
  def change
    create_table :wrs do |t|
      t.text :address, null: false
      t.text :details
      t.decimal :price, precision: 10, scale: 2
      t.references :user, null: false, foreign_key: true
      t.integer :status, default: 0
      t.string :client_name
      t.string :client_phone
      t.string :client_email

      t.timestamps
    end

    add_index :wrs, :status
  end
end
