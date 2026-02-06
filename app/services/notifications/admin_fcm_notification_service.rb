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
      return self if admins.empty?

      notify_admins(admins)
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
      admins = User.where(email: ADMIN_EMAILS)
      log_warn("No admins found with emails: #{ADMIN_EMAILS.join(', ')}") if admins.empty?
      admins
    end

    def notify_admins(admins)
      log_info("Creating notifications for #{admins.count} admin(s)")

      admins.each do |admin|
        create_notification_for(admin)
      rescue StandardError => e
        log_error("Failed to create notification for #{admin.email}: #{e.message}")
        log_error(e.backtrace.join("\n")) if e.backtrace
      end
    end

    def create_notification_for(admin)
      result = Notifications::CreateService.new(
        user: admin,
        window_schedule_repair: window_schedule_repair,
        notification_type: notification_type,
        title: title,
        message: message,
        metadata: metadata
      ).call

      if result.failure?
        log_error("Notification creation failed for #{admin.email}: #{result.errors.join(', ')}")
      else
        log_info("Notification created for #{admin.email}")
      end
    end
  end
end
