# frozen_string_literal: true

module Notifications
  class AdminNotificationService < ApplicationService
    BATCH_SIZE = 50
    RATE_LIMIT_DELAY = 0.1 # seconds between batches

    ADMIN_EMAILS = if Rails.env.development?
                     ['admin@bullet.co.uk']
                   else
                     ['mm@bulletservices.co.uk',
                      'danielsilas32@gmail.com']
                   end

    attribute :work_order
    attribute :notification_type
    attribute :title
    attribute :message
    attribute :metadata, default: -> { {} }

    def call
      return self if validate_attributes.failure?

      return self if admin_recipients.empty?

      send_notifications

      self
    end

    private

    def admin_recipients
      @admin_recipients ||= begin
        role_admin_ids = User.admin.pluck(:id)
        email_admin_ids = User.where(email: ADMIN_EMAILS).pluck(:id)
        combined_ids = (role_admin_ids + email_admin_ids).uniq

        admins = User.where(id: combined_ids)
        log_warn("No admin users found for notifications (emails: #{ADMIN_EMAILS.join(', ')})") if admins.empty?
        admins
      rescue StandardError => e
        log_error("Failed to load admin recipients: #{e.message}")
        []
      end
    end

    def admin_count
      @admin_count ||= User.admin.count
    end

    def validate_attributes
      add_error('Work order is required') unless work_order
      add_error('Notification type is required') unless notification_type
      add_error('Title is required') unless title
      self
    end

    def send_notifications
      if admin_count > BATCH_SIZE
        queue_batch_notification_job
        send_notifications_to_email_admins_only
      else
        send_notifications_synchronously
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

    def send_notifications_to_email_admins_only
      email_admins = User.where(email: ADMIN_EMAILS)
                         .where.not(id: User.admin.select(:id))
      email_admins.find_each(batch_size: BATCH_SIZE) do |admin|
        safely_create_notification_for(admin)
      end
    rescue StandardError => e
      log_error("Failed sending email-admin notifications: #{e.message}")
    end

    def send_notifications_synchronously
      admin_recipients.find_each(batch_size: BATCH_SIZE) do |admin|
        safely_create_notification_for(admin)
        sleep(RATE_LIMIT_DELAY) if admin_count > 10 # Rate limiting
      end
    end

    def safely_create_notification_for(admin)
      create_notification_for(admin)
    rescue StandardError => e
      log_error("Failed to create notification for #{admin.email}: #{e.message}")
      log_error(e.backtrace.join("\n")) if e.backtrace
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
