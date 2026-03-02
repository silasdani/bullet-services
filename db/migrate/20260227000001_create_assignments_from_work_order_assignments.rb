# frozen_string_literal: true

class CreateAssignmentsFromWorkOrderAssignments < ActiveRecord::Migration[8.0]
  def up
    unless table_exists?(:assignments)
      create_table :assignments do |t|
        t.references :user, null: false, foreign_key: true
        t.references :building, null: false, foreign_key: true
        t.references :assigned_by_user, foreign_key: { to_table: :users }
        t.timestamps
      end
      add_index :assignments, %i[user_id building_id], unique: true
    end

    backfill_assignments

    drop_table :work_order_assignments if table_exists?(:work_order_assignments)
  end

  def down
    create_table :work_order_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :work_order, null: false, foreign_key: true
      t.references :assigned_by_user, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :work_order_assignments, %i[user_id work_order_id], unique: true

    return unless table_exists?(:assignments)

    select_all('SELECT id, user_id, building_id, assigned_by_user_id FROM assignments').each do |a|
      work_order_ids = select_all("SELECT id FROM work_orders WHERE building_id = #{quote(a['building_id'])}").map { |r| r['id'] }
      work_order_ids.each do |wo_id|
        execute <<-SQL.squish
          INSERT INTO work_order_assignments (user_id, work_order_id, assigned_by_user_id, created_at, updated_at)
          VALUES (#{quote(a['user_id'])}, #{quote(wo_id)}, #{a['assigned_by_user_id'].nil? ? 'NULL' : quote(a['assigned_by_user_id'])}, NOW(), NOW())
          ON CONFLICT (user_id, work_order_id) DO NOTHING
        SQL
      end
    end

    drop_table :assignments
  end

  private

  def backfill_assignments
    return unless table_exists?(:work_order_assignments)

    execute(<<-SQL.squish)
      INSERT INTO assignments (user_id, building_id, assigned_by_user_id, created_at, updated_at)
      SELECT sub.user_id, sub.building_id, sub.assigned_by_user_id, sub.created_at, sub.updated_at
      FROM (
        SELECT woa.user_id, wo.building_id, woa.assigned_by_user_id, woa.created_at, woa.updated_at,
               ROW_NUMBER() OVER (PARTITION BY woa.user_id, wo.building_id ORDER BY woa.created_at DESC) AS rn
        FROM work_order_assignments woa
        INNER JOIN work_orders wo ON wo.id = woa.work_order_id
      ) sub
      WHERE sub.rn = 1
    SQL
  end
end
