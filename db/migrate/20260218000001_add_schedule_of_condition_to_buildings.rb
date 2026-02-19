# frozen_string_literal: true

class AddScheduleOfConditionToBuildings < ActiveRecord::Migration[7.1]
  def change
    add_column :buildings, :schedule_of_condition_notes, :text
  end
end
