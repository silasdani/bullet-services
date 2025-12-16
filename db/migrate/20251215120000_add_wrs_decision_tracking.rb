# frozen_string_literal: true

class AddWrsDecisionTracking < ActiveRecord::Migration[8.0]
  def change
    change_table :window_schedule_repairs, bulk: true do |t|
      t.datetime :decision_at
      t.string :decision
      t.string :decision_client_email
      t.string :decision_client_name
      t.datetime :terms_accepted_at
      t.string :terms_version
    end
  end
end

