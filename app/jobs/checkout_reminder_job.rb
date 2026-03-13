# frozen_string_literal: true

class CheckoutReminderJob < ApplicationJob
  queue_as :default

  def perform
    active_entries = TimeEntry.clocked_in.includes(:user, :building)

    active_entries.find_each do |entry|
      Notifications::CreateService.new(
        user: entry.user,
        notification_type: :checkout_reminder,
        title: 'Check-out reminder',
        message: 'Did you check out?',
        metadata: {
          time_entry_id: entry.id,
          building_name: entry.building&.name
        }
      ).call
    end
  end
end
