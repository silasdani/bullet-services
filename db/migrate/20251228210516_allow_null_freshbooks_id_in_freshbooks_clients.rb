class AllowNullFreshbooksIdInFreshbooksClients < ActiveRecord::Migration[8.0]
  def change
    change_column_null :freshbooks_clients, :freshbooks_id, true
  end
end
