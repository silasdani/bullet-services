# frozen_string_literal: true

class CreateTimeEntriesAndBackfill < ActiveRecord::Migration[8.0]
  def up
    create_table :time_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :work_order, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.decimal :start_lat, precision: 10, scale: 7
      t.decimal :start_lng, precision: 10, scale: 7
      t.decimal :end_lat, precision: 10, scale: 7
      t.decimal :end_lng, precision: 10, scale: 7
      t.string :start_address
      t.string :end_address
      t.references :ongoing_work, null: true, foreign_key: true
      t.timestamps
    end

    add_index :time_entries, %i[user_id starts_at]
    add_index :time_entries, %i[work_order_id starts_at]
    add_index :time_entries, :ends_at, where: 'ends_at IS NOT NULL'

    backfill_from_work_sessions
  end

  def down
    drop_table :time_entries
  end

  private

  def backfill_from_work_sessions
    return unless table_exists?(:work_sessions)

    execute(<<-SQL.squish)
      INSERT INTO time_entries (user_id, work_order_id, starts_at, ends_at, start_lat, start_lng, end_lat, end_lng, start_address, end_address, ongoing_work_id, created_at, updated_at)
      SELECT
        user_id,
        work_order_id,
        checked_in_at,
        checked_out_at,
        NULL,
        NULL,
        latitude,
        longitude,
        NULL,
        address,
        ongoing_work_id,
        created_at,
        updated_at
      FROM work_sessions
      WHERE deleted_at IS NULL
    SQL
  end
end
