# frozen_string_literal: true

class CreateFreshbooksPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :freshbooks_payments do |t|
      t.string :freshbooks_id, null: false
      t.string :freshbooks_invoice_id, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :date, null: false
      t.string :payment_method
      t.string :currency_code
      t.text :notes
      t.jsonb :raw_data

      t.timestamps
    end

    add_index :freshbooks_payments, :freshbooks_id, unique: true
    add_index :freshbooks_payments, :freshbooks_invoice_id
    add_index :freshbooks_payments, :date
  end
end
