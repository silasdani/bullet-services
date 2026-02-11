# frozen_string_literal: true

class ReplaceBuildingAssignmentsWithWorkOrderAssignments < ActiveRecord::Migration[8.0]
  def up
    # Create work_order_assignments
    create_table :work_order_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :work_order, null: false, foreign_key: true
      t.bigint :assigned_by_user_id

      t.timestamps
    end

    add_index :work_order_assignments, %i[user_id work_order_id], unique: true
    add_index :work_order_assignments, :assigned_by_user_id
    add_foreign_key :work_order_assignments, :users, column: :assigned_by_user_id

    # Migrate existing building assignments to work order assignments
    # Each user assigned to a building gets assigned to all work orders in that building
    execute <<-SQL.squish
      INSERT INTO work_order_assignments (user_id, work_order_id, assigned_by_user_id, created_at, updated_at)
      SELECT ba.user_id, wo.id, ba.assigned_by_user_id, NOW(), NOW()
      FROM building_assignments ba
      INNER JOIN work_orders wo ON wo.building_id = ba.building_id AND wo.deleted_at IS NULL
      ON CONFLICT (user_id, work_order_id) DO NOTHING
    SQL

    # Drop building_assignments
    drop_table :building_assignments
  end

  def down
    create_table :building_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :building, null: false, foreign_key: true
      t.bigint :assigned_by_user_id

      t.timestamps
    end

    add_index :building_assignments, %i[user_id building_id], unique: true
    add_index :building_assignments, :assigned_by_user_id
    add_foreign_key :building_assignments, :users, column: :assigned_by_user_id

    # Migrate back: derive building assignments from work order assignments
    execute <<-SQL.squish
      INSERT INTO building_assignments (user_id, building_id, assigned_by_user_id, created_at, updated_at)
      SELECT DISTINCT ON (woa.user_id, wo.building_id) woa.user_id, wo.building_id, woa.assigned_by_user_id, NOW(), NOW()
      FROM work_order_assignments woa
      INNER JOIN work_orders wo ON wo.id = woa.work_order_id AND wo.deleted_at IS NULL
      ORDER BY woa.user_id, wo.building_id
    SQL

    drop_table :work_order_assignments
  end
end
