# frozen_string_literal: true

class BackfillOngoingWorkIdOnWorkSessions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Link existing work_sessions to their most likely ongoing_work
    # by matching user_id, work_order_id, and overlapping dates.
    # Processes in batches to avoid locking the table.
    WorkSession.where(ongoing_work_id: nil).find_each(batch_size: 500) do |session|
      ongoing_work = OngoingWork
        .where(user_id: session.user_id, work_order_id: session.work_order_id)
        .where('work_date <= ?', session.checked_in_at.to_date + 1.day)
        .order(work_date: :desc)
        .first

      session.update_column(:ongoing_work_id, ongoing_work.id) if ongoing_work
    end
  end

  def down
    # Reversible: clear the backfilled values
    WorkSession.where.not(ongoing_work_id: nil).update_all(ongoing_work_id: nil)
  end
end
