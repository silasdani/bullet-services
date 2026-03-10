# frozen_string_literal: true

class RemoveDefaultFromAssignmentRole < ActiveRecord::Migration[7.2]
  def change
    change_column_default :assignments, :role, from: 1, to: nil
    change_column_null :assignments, :role, true
  end
end
