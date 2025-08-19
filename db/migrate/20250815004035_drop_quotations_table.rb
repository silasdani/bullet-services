class DropQuotationsTable < ActiveRecord::Migration[8.0]
  def change
    drop_table :wrs if table_exists?(:wrs)
  end
end
