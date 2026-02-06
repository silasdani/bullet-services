# frozen_string_literal: true

module Notifications
  class AdminFcmNotificationService < ApplicationService
    ADMIN_EMAILS = if Rails.env.development?
                     ['admin@bullet.co.uk']
                   else
                     ['mm@bulletservices.co.uk',
                      'danielsilas32@gmail.com']
                   end

    attribute :window_schedule_repair
    attribute :notification_type
    attribute :title
    attribute :message
    attribute :metadata, default: -> { {} }

    def call
      return self if validate_attributes.failure?

      admins = find_admins
      if admins.empty?
        log_warn("No admins found with emails: #{ADMIN_EMAILS.join(', ')}")
        return self
      end

      log_info("Found #{admins.count} admin(s) to notify")
      admins.each do |admin|
        if admin.fcm_token.present?
          log_info("Sending FCM notification to admin: #{admin.email}")
          result = send_fcm_notification(admin)
          log_error("Failed to send FCM notification to #{admin.email}: #{result.errors.join(', ')}") if result.failure?
        else
          log_warn("Admin #{admin.email} has no FCM token, skipping notification")
        end
      end
      self
    end

    private

    def validate_attributes
      add_error('Window schedule repair is required') unless window_schedule_repair
      add_error('Notification type is required') unless notification_type
      add_error('Title is required') unless title
      self
    end

    def find_admins
      User.where(email: ADMIN_EMAILS)
    end

    def send_fcm_notification(admin)
      Fcm::SendNotificationService.new(
        user: admin,
        title: title,
        body: message || title,
        data: build_push_data
      ).call
    rescue StandardError => e
      log_error("Exception sending FCM notification to #{admin.email}: #{e.message}")
      log_error(e.backtrace.join("\n")) if e.backtrace
      add_error("Failed to send notification to #{admin.email}")
      self
    end

    def build_push_data
      data = {
        notification_type: notification_type.to_s
      }

      data[:window_schedule_repair_id] = window_schedule_repair.id.to_s if window_schedule_repair
      data.merge((metadata || {}).transform_keys(&:to_s))
    end
  end
end
