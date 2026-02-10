# frozen_string_literal: true

class MigrateCheckInsToWorkSessions < ActiveRecord::Migration[8.0]
  def up
    # Migrate check-ins to work_sessions
    # This is a complex migration that pairs check-ins with check-outs
    execute <<-SQL
      INSERT INTO work_sessions (
        user_id,
        window_schedule_repair_id,
        checked_in_at,
        checked_out_at,
        latitude,
        longitude,
        address,
        created_at,
        updated_at
      )
      SELECT 
        ci_in.user_id,
        ci_in.window_schedule_repair_id,
        ci_in.timestamp AS checked_in_at,
        ci_out.timestamp AS checked_out_at,
        ci_in.latitude,
        ci_in.longitude,
        ci_in.address,
        ci_in.created_at,
        COALESCE(ci_out.updated_at, ci_in.updated_at) AS updated_at
      FROM check_ins ci_in
      LEFT OUTER JOIN check_ins ci_out ON 
        ci_out.user_id = ci_in.user_id
        AND ci_out.window_schedule_repair_id = ci_in.window_schedule_repair_id
        AND ci_out.action = 1 -- check_out
        AND ci_out.id > ci_in.id
        AND NOT EXISTS (
          SELECT 1 FROM check_ins ci_between
          WHERE ci_between.user_id = ci_in.user_id
          AND ci_between.window_schedule_repair_id = ci_in.window_schedule_repair_id
          AND ci_between.id > ci_in.id
          AND ci_between.id < ci_out.id
          AND ci_between.action = 0 -- another check_in between
        )
      WHERE ci_in.action = 0 -- check_in
      AND NOT EXISTS (
        SELECT 1 FROM check_ins ci_earlier
        WHERE ci_earlier.user_id = ci_in.user_id
        AND ci_earlier.window_schedule_repair_id = ci_in.window_schedule_repair_id
        AND ci_earlier.action = 0 -- check_in
        AND ci_earlier.id < ci_in.id
        AND NOT EXISTS (
          SELECT 1 FROM check_ins ci_out_earlier
          WHERE ci_out_earlier.user_id = ci_earlier.user_id
          AND ci_out_earlier.window_schedule_repair_id = ci_earlier.window_schedule_repair_id
          AND ci_out_earlier.action = 1 -- check_out
          AND ci_out_earlier.id > ci_earlier.id
          AND ci_out_earlier.id < ci_in.id
        )
      )
    SQL
  end

  def down
    # Migrate work_sessions back to check_ins
    execute <<-SQL
      INSERT INTO check_ins (
        user_id,
        window_schedule_repair_id,
        action,
        timestamp,
        latitude,
        longitude,
        address,
        created_at,
        updated_at
      )
      SELECT 
        user_id,
        window_schedule_repair_id,
        0, -- check_in
        checked_in_at,
        latitude,
        longitude,
        address,
        created_at,
        updated_at
      FROM work_sessions
      
      UNION ALL
      
      SELECT 
        user_id,
        window_schedule_repair_id,
        1, -- check_out
        checked_out_at,
        latitude,
        longitude,
        address,
        created_at,
        updated_at
      FROM work_sessions
      WHERE checked_out_at IS NOT NULL
    SQL
  end
end
