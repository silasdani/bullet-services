class ChangeDefaultUserRoleToContractor < ActiveRecord::Migration[8.0]
  def change
    change_column_default :users, :role, from: 0, to: 1
  end
end
