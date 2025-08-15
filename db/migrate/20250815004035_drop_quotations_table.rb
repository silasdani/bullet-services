class DropQuotationsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :quotations if table_exists?(:quotations)
  end
end
