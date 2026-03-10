# frozen_string_literal: true

class AddRoleToAssignments < ActiveRecord::Migration[7.2]
  def change
    add_column :assignments, :role, :integer, null: false, default: 1
    # Values mirror User.role minus :admin (2) and :client (0):
    #   contractor: 1, surveyor: 3, general_contractor: 4, supervisor: 5, contract_manager: 6
  end
end
