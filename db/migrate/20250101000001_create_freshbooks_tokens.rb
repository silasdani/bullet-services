# frozen_string_literal: true

class CreateFreshbooksTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :freshbooks_tokens do |t|
      t.text :access_token, null: false
      t.text :refresh_token, null: false
      t.datetime :token_expires_at, null: false
      t.string :business_id, null: false
      t.string :user_freshbooks_id

      t.timestamps
    end

    add_index :freshbooks_tokens, :business_id, unique: true
  end
end
