# frozen_string_literal: true

class CleanupDeletedUsersJob < ApplicationJob
  queue_as :default

  # Permanently deletes users who were soft-deleted 30+ days ago.
  # Run daily via config/recurring.yml when using Solid Queue.
  def perform
    deleted_count = 0
    error_count = 0

    User.pending_permanent_deletion.find_each do |user|
      user.destroy
      deleted_count += 1
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError => e
      error_count += 1
      Rails.logger.warn(
        "CleanupDeletedUsersJob: could not permanently delete user #{user.id}: #{e.message}"
      )
    end

    Rails.logger.info(
      "CleanupDeletedUsersJob: permanently deleted #{deleted_count} user(s), skipped #{error_count} due to restrictions"
    )
  end
end
