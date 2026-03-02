# frozen_string_literal: true

class RenameWorkOrderDecisionsToDecisions < ActiveRecord::Migration[8.0]
  def up
    rename_table :work_order_decisions, :decisions
  end

  def down
    rename_table :decisions, :work_order_decisions
  end
end
