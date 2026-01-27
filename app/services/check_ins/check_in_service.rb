# frozen_string_literal: true

module CheckIns
  class CheckInService < ApplicationService
    include AddressResolver
    attribute :user
    attribute :window_schedule_repair
    attribute :latitude
    attribute :longitude
    attribute :address
    attribute :timestamp, default: -> { Time.current }

    attr_accessor :check_in

    def call
      return self if validate_active_check_in.failure?
      return self if create_check_in.failure?

      create_notification
      self
    end

    private

    def validate_active_check_in
      add_error('You already have an active check-in. Please check out first.') if active_check_in_exists?
      self
    end

    def active_check_in_exists?
      CheckIn.active_for(user, window_schedule_repair).exists?
    end

    def create_check_in
      @check_in = CheckIn.new(
        user: user,
        window_schedule_repair: window_schedule_repair,
        action: :check_in,
        latitude: latitude,
        longitude: longitude,
        address: resolve_address,
        timestamp: timestamp
      )

      if @check_in.save
        log_info("Check-in created: #{@check_in.id}")
      else
        add_errors(@check_in.errors.full_messages)
      end
      self
    end

    def create_notification
      Notifications::CreateService.new(
        user: window_schedule_repair.user,
        window_schedule_repair: window_schedule_repair,
        notification_type: :check_in,
        title: 'Check-in Notification',
        message: build_check_in_message,
        metadata: build_check_in_metadata
      ).call
    end

    def build_check_in_message
      "#{user.name || user.email} checked in at #{window_schedule_repair.name}"
    end

    def build_check_in_metadata
      {
        contractor_id: user.id,
        contractor_name: user.name || user.email,
        check_in_id: check_in.id,
        location: check_in.address || "#{latitude}, #{longitude}"
      }
    end
  end
end
