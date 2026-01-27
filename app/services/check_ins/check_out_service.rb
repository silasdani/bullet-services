# frozen_string_literal: true

module CheckIns
  class CheckOutService < ApplicationService
    include AddressResolver
    attribute :user
    attribute :window_schedule_repair
    attribute :latitude
    attribute :longitude
    attribute :address
    attribute :hourly_rate, default: -> { 0 }
    attribute :timestamp, default: -> { Time.current }

    attr_accessor :check_out

    def call
      return self if validate_check_in.failure?
      return self if validate_photos_uploaded.failure?
      return self if validate_timestamps.failure?
      return self if create_check_out.failure?

      create_notification
      self
    end

    private

    def validate_check_in
      add_error('No active check-in found. Please check in first.') unless check_in_record
      self
    end

    def validate_photos_uploaded
      add_error('Cannot check out. Please upload work photos first.') unless photos_uploaded?
      self
    end

    def check_in_record
      @check_in_record ||= CheckIn.active_for(user, window_schedule_repair).first
    end

    def photos_uploaded?
      OngoingWork.where(
        window_schedule_repair: window_schedule_repair,
        user: user
      ).where('work_date >= ?', check_in_record.timestamp.to_date).exists?
    end

    def create_check_out
      @check_out = CheckIn.new(
        user: user,
        window_schedule_repair: window_schedule_repair,
        action: :check_out,
        latitude: latitude,
        longitude: longitude,
        address: resolve_address,
        timestamp: timestamp
      )

      if @check_out.save
        log_info("Check-out created: #{@check_out.id}")
      else
        add_errors(@check_out.errors.full_messages)
      end
      self
    end

    def validate_timestamps
      return self unless check_in_record

      check_out_time = timestamp || Time.current
      add_error('Check-out time must be after check-in time') if check_out_time <= check_in_record.timestamp
      self
    end

    def calculate_hours_worked
      return 0 unless check_in_record && check_out

      duration_seconds = check_out.timestamp - check_in_record.timestamp
      (duration_seconds / 1.hour).round(2)
    end

    def create_notification
      hours_worked = calculate_hours_worked
      Notifications::CreateService.new(
        user: window_schedule_repair.user,
        window_schedule_repair: window_schedule_repair,
        notification_type: :check_out,
        title: 'Check-out Notification',
        message: build_check_out_message(hours_worked),
        metadata: build_check_out_metadata(hours_worked)
      ).call
    end

    def build_check_out_message(hours_worked)
      "#{user.name || user.email} checked out from #{window_schedule_repair.name}. " \
        "Hours worked: #{hours_worked}"
    end

    def build_check_out_metadata(hours_worked)
      {
        contractor_id: user.id,
        contractor_name: user.name || user.email,
        check_out_id: check_out.id,
        hours_worked: hours_worked,
        location: check_out.address || "#{latitude}, #{longitude}"
      }
    end
  end
end
