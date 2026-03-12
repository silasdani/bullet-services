# frozen_string_literal: true

class CheckoutReminderJob < ApplicationJob
  queue_as :default

  def perform
    active_entries = TimeEntry.clocked_in.includes(:user, :work_order)

    active_entries.find_each do |entry|
      next unless entry.user&.contractor? || entry.user&.general_contractor?

      Notifications::CreateService.new(
        user: entry.user,
        work_order: entry.work_order,
        notification_type: :checkout_reminder,
        title: 'Check-out reminder',
        message: 'Did you check out?',
        metadata: {
          time_entry_id: entry.id,
          work_order_name: entry.work_order&.name
        }
      ).call
    end
  end
end
