class FixUserUidFields < ActiveRecord::Migration[8.0]
  def up
    # Fix existing users where UID is empty or doesn't match email
    User.where("uid = '' OR uid IS NULL OR uid != email").find_each do |user|
      if user.email.present?
        user.update_column(:uid, user.email)
        puts "Fixed UID for user #{user.id}: #{user.email}"
      end
    end
  end

  def down
    # This migration is not reversible as we can't determine original UID values
    raise ActiveRecord::IrreversibleMigration
  end
end
