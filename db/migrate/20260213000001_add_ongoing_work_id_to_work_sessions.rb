# frozen_string_literal: true

class AddOngoingWorkIdToWorkSessions < ActiveRecord::Migration[8.0]
  def change
    add_reference :work_sessions, :ongoing_work, null: true, foreign_key: true
  end
end
