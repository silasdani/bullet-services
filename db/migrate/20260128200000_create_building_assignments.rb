# frozen_string_literal: true

class CreateBuildingAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :building_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :building, null: false, foreign_key: true
      t.bigint :assigned_by_user_id

      t.timestamps
    end

    add_index :building_assignments, %i[user_id building_id], unique: true
    add_index :building_assignments, :assigned_by_user_id
    add_foreign_key :building_assignments, :users, column: :assigned_by_user_id
  end
end
