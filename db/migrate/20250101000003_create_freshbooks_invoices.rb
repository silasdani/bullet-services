# frozen_string_literal: true

class CreateFreshbooksInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :freshbooks_invoices do |t|
      t.string :freshbooks_id, null: false
      t.string :freshbooks_client_id, null: false
      t.string :invoice_number
      t.string :status
      t.decimal :amount, precision: 10, scale: 2
      t.decimal :amount_outstanding, precision: 10, scale: 2
      t.date :date
      t.date :due_date
      t.string :currency_code
      t.text :notes
      t.string :pdf_url
      t.jsonb :raw_data
      t.bigint :invoice_id # Reference to local Invoice model

      t.timestamps
    end

    add_index :freshbooks_invoices, :freshbooks_id, unique: true
    add_index :freshbooks_invoices, :freshbooks_client_id
    add_index :freshbooks_invoices, :invoice_id
    add_index :freshbooks_invoices, :status
  end
end
