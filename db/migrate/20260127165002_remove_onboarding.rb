class RemoveOnboarding < ActiveRecord::Migration[8.0]
  def change
    # Remove foreign key constraint first
    remove_foreign_key :onboarding_completions, :users if foreign_key_exists?(:onboarding_completions, :users)

    # Drop the onboarding_completions table
    drop_table :onboarding_completions if table_exists?(:onboarding_completions)

    # Remove indexes from users table
    remove_index :users, :onboarding_step if index_exists?(:users, :onboarding_step)
    remove_index :users, :onboarding_completed_at if index_exists?(:users, :onboarding_completed_at)

    # Remove columns from users table
    remove_column :users, :onboarding_step, :integer if column_exists?(:users, :onboarding_step)
    remove_column :users, :onboarding_completed_at, :datetime if column_exists?(:users, :onboarding_completed_at)
  end
end
