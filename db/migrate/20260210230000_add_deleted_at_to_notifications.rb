# frozen_string_literal: true

class AddDeletedAtToNotifications < ActiveRecord::Migration[8.0]
  def change
    add_column :notifications, :deleted_at, :datetime
    add_index :notifications, :deleted_at
  end
end

