# frozen_string_literal: true

class AddNameFieldsToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :phone_no, :string

    # Backfill first_name/last_name from name for existing users
    reversible do |dir|
      dir.up do
        User.unscoped.find_each do |user|
          first, last = user.name.present? ? user.name.split(' ', 2) : ['Unknown', '']
          user.update_columns(first_name: first, last_name: last.to_s)
        end
      end
    end

    remove_column :users, :name, :string
  end

  def down
    add_column :users, :name, :string
    User.unscoped.find_each do |user|
      user.update_columns(name: "#{user.first_name} #{user.last_name}")
    end
    remove_column :users, :first_name, :string
    remove_column :users, :last_name, :string
    remove_column :users, :phone_no, :string
  end
end
