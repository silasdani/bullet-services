class AddReadAtToNotifications < ActiveRecord::Migration[8.0]
  def change
    add_column :notifications, :read_at, :datetime
    add_index :notifications, :read_at
    # Keep 'read' boolean for backward compatibility, but read_at is the source of truth
  end
end
