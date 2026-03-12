# frozen_string_literal: true

class AutoCheckoutJob < ApplicationJob
  queue_as :default

  def perform
    active_entries = TimeEntry.clocked_in.includes(:user, :work_order)

    active_entries.find_each do |entry|
      checkout_entry(entry)
    rescue StandardError => e
      Rails.logger.error("[AutoCheckoutJob] Failed for TimeEntry##{entry.id}: #{e.message}")
    end
  end

  private

  def checkout_entry(entry)
    entry.update!(
      ends_at: end_of_day_for(entry),
      auto_checkout: true
    )

    return unless entry.user

    Notifications::CreateService.new(
      user: entry.user,
      work_order: entry.work_order,
      notification_type: :auto_checkout,
      title: 'Automatic check-out',
      message: 'You have been automatically checked out.',
      metadata: {
        time_entry_id: entry.id,
        work_order_name: entry.work_order&.name,
        auto_checkout: true
      }
    ).call
  end

  def end_of_day_for(entry)
    entry.starts_at.end_of_day
  end
end
