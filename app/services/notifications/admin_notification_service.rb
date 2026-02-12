# frozen_string_literal: true

module Notifications
  class AdminNotificationService < ApplicationService
    BATCH_SIZE = 50
    RATE_LIMIT_DELAY = 0.1 # seconds between batches

    attribute :work_order
    attribute :notification_type
    attribute :title
    attribute :message
    attribute :metadata

    def call
      return self if validate_attributes.failure?

      if admin_count > BATCH_SIZE
        queue_batch_notification_job
      else
        send_notifications_synchronously
      end

      self
    end

    private

    def admin_count
      @admin_count ||= User.admin.count
    end

    def validate_attributes
      add_error('Work order is required') unless work_order
      add_error('Notification type is required') unless notification_type
      add_error('Title is required') unless title
      self
    end

    def send_notifications_synchronously
      User.admin.find_each(batch_size: BATCH_SIZE) do |admin|
        create_notification_for(admin)
        sleep(RATE_LIMIT_DELAY) if admin_count > 10 # Rate limiting
      end
    end

    def queue_batch_notification_job
      BatchAdminNotificationJob.perform_later(
        work_order_id: work_order.id,
        notification_type: notification_type,
        title: title,
        message: message,
        metadata: metadata
      )
    end

    def create_notification_for(admin)
      Notifications::CreateService.new(
        user: admin,
        work_order: work_order,
        notification_type: notification_type,
        title: title,
        message: message,
        metadata: metadata
      ).call
    end
  end
end
