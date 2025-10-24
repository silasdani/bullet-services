class CreateInvoicesTable < ActiveRecord::Migration[8.0]
  def change
    create_table :invoices do |t|
      t.string :name
      t.string :slug
      t.string :webflow_item_id
      t.boolean :is_archived
      t.boolean :is_draft
      t.string :webflow_created_on
      t.string :webflow_published_on
      t.string :freshbooks_client_id
      t.string :job
      t.string :wrs_link
      t.decimal :included_vat_amount
      t.decimal :excluded_vat_amount
      t.string :status_color
      t.string :status
      t.string :final_status
      t.string :invoice_pdf_link

      t.timestamps
    end
  end
end
