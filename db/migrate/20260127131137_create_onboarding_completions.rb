class CreateOnboardingCompletions < ActiveRecord::Migration[8.0]
  def change
    create_table :onboarding_completions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :step, null: false
      t.jsonb :metadata
      t.datetime :completed_at, null: false

      t.timestamps
    end

    add_index :onboarding_completions, [:user_id, :step]
  end
end
