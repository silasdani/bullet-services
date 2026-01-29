class AddOnboardingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :onboarding_step, :integer, default: 0, null: false
    add_column :users, :onboarding_completed_at, :datetime

    add_index :users, :onboarding_step
    add_index :users, :onboarding_completed_at

    # Set existing contractors to completed
    execute <<-SQL
      UPDATE users
      SET onboarding_step = 4, onboarding_completed_at = NOW()
      WHERE role = 1 AND onboarding_step = 0
    SQL
  end
end
