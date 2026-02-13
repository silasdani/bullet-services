# frozen_string_literal: true

class MigrateDecisionsToWorkOrderDecisions < ActiveRecord::Migration[8.0]
  def up
    # Migrate existing decision data to new table
    execute <<-SQL
      INSERT INTO work_order_decisions (
        window_schedule_repair_id,
        decision,
        decision_at,
        client_email,
        client_name,
        terms_accepted_at,
        terms_version,
        created_at,
        updated_at
      )
      SELECT 
        id,
        decision,
        decision_at,
        decision_client_email,
        decision_client_name,
        terms_accepted_at,
        terms_version,
        COALESCE(decision_at, created_at),
        updated_at
      FROM window_schedule_repairs
      WHERE decision IS NOT NULL AND decision_at IS NOT NULL
    SQL

    # Remove decision columns from window_schedule_repairs
    remove_column :window_schedule_repairs, :decision_at, :datetime
    remove_column :window_schedule_repairs, :decision, :string
    remove_column :window_schedule_repairs, :decision_client_email, :string
    remove_column :window_schedule_repairs, :decision_client_name, :string
    remove_column :window_schedule_repairs, :terms_accepted_at, :datetime
    remove_column :window_schedule_repairs, :terms_version, :string
  end

  def down
    # Add columns back
    add_column :window_schedule_repairs, :decision_at, :datetime
    add_column :window_schedule_repairs, :decision, :string
    add_column :window_schedule_repairs, :decision_client_email, :string
    add_column :window_schedule_repairs, :decision_client_name, :string
    add_column :window_schedule_repairs, :terms_accepted_at, :datetime
    add_column :window_schedule_repairs, :terms_version, :string

    # Migrate data back
    execute <<-SQL
      UPDATE window_schedule_repairs wrs
      SET 
        decision = wod.decision,
        decision_at = wod.decision_at,
        decision_client_email = wod.client_email,
        decision_client_name = wod.client_name,
        terms_accepted_at = wod.terms_accepted_at,
        terms_version = wod.terms_version
      FROM work_order_decisions wod
      WHERE wod.window_schedule_repair_id = wrs.id
    SQL
  end
end
