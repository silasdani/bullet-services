class AddWebflowImportColumnsToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :webflow_collection_id, :string
    add_column :invoices, :webflow_updated_on, :string
    add_column :invoices, :flat_address, :string
    add_column :invoices, :generated_by, :string
  end
end
