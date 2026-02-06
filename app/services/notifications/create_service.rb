# frozen_string_literal: true

module Notifications
  class CreateService < ApplicationService
    attribute :user
    attribute :window_schedule_repair, default: -> {}
    attribute :notification_type
    attribute :title
    attribute :message, default: -> {}
    attribute :metadata, default: -> { {} }

    attr_accessor :notification

    def call
      return self if validate_attributes.failure?
      return self if create_notification.failure?

      self
    end

    private

    def validate_attributes
      add_error('User is required') unless user
      add_error('Notification type is required') unless notification_type
      add_error('Title is required') unless title
      self
    end

    def create_notification
      @notification = Notification.new(
        user: user,
        window_schedule_repair: window_schedule_repair,
        notification_type: notification_type,
        title: title,
        message: message,
        metadata: metadata
      )

      if @notification.save
        log_info("Notification created: #{@notification.id}")
        send_push_notification
      else
        add_errors(@notification.errors.full_messages)
      end
      self
    end

    def send_push_notification
      return unless user.fcm_token.present?

      SendFcmNotificationJob.perform_later(
        user.id,
        title,
        message || title,
        build_push_data
      )
    rescue StandardError => e
      log_error("Failed to queue FCM: #{e.message}")
    end

    def build_push_data
      data = {
        notification_id: @notification.id.to_s,
        notification_type: notification_type.to_s
      }

      data[:window_schedule_repair_id] = window_schedule_repair.id.to_s if window_schedule_repair
      data.merge(metadata.transform_keys(&:to_s).transform_values(&:to_s))
    end
  end
end
