class AddWebflowAccessToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :webflow_access, :boolean, default: false
  end
end
