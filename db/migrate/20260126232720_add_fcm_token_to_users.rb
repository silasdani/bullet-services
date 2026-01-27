class AddFcmTokenToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :fcm_token, :string
    add_index :users, :fcm_token, where: 'fcm_token IS NOT NULL'
  end
end
