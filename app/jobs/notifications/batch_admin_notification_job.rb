# frozen_string_literal: true

module Notifications
  class BatchAdminNotificationJob < ApplicationJob
    queue_as :notifications
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(window_schedule_repair_id, notification_type, title, message, metadata)
      wrs = WindowScheduleRepair.find(window_schedule_repair_id)

      User.admin.find_each(batch_size: 50) do |admin|
        Notifications::CreateService.new(
          user: admin,
          window_schedule_repair: wrs,
          notification_type: notification_type,
          title: title,
          message: message,
          metadata: metadata
        ).call

        sleep(0.1) # Rate limiting
      end
    end
  end
end
