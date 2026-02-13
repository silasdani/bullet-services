# frozen_string_literal: true

module CheckIns
  class CheckOutService < ApplicationService
    include AddressResolver
    attribute :user
    attribute :work_order
    attribute :latitude
    attribute :longitude
    attribute :address
    attribute :hourly_rate, default: -> { 0 }
    attribute :timestamp, default: -> { Time.current }

    attr_accessor :check_out

    def call
      ActiveRecord::Base.transaction do
        return self if validate_check_in.failure?
        return self if validate_photos_uploaded.failure?
        return self if validate_timestamps.failure?
        return self if create_check_out.failure?

        create_notification
        self
      end
    rescue ActiveRecord::RecordInvalid => e
      add_errors(e.record.errors.full_messages)
      self
    end

    def hours_worked
      calculate_hours_worked
    end

    private

    def validate_check_in
      add_error('No active check-in found. Please check in first.') unless check_in_record
      self
    end

    def validate_photos_uploaded
      unless photos_uploaded?
        add_error('Cannot check out. Please upload work photos first.')
        add_error('At least one photo is required to document completed work.')
        return self
      end

      # Additional validation: ensure photos are from today
      unless photos_from_today?
        add_error('Photos must be uploaded today to check out.')
        return self
      end

      self
    end

    def check_in_record
      @check_in_record ||= CheckIn.active_for(user, work_order).first
    end

    def photos_uploaded?
      return false unless check_in_record

      check_in_date = check_in_record.timestamp.to_date

      OngoingWork
        .where(
          work_order: work_order,
          user: user
        )
        .where('work_date >= ?', check_in_date)
        .joins(:images_attachments)
        .where('active_storage_attachments.created_at >= ?', check_in_date.beginning_of_day)
        .exists?
    end

    def photos_from_today?
      return false unless check_in_record

      OngoingWork
        .where(
          work_order: work_order,
          user: user
        )
        .where('work_date >= ?', check_in_record.timestamp.to_date)
        .joins(:images_attachments)
        .where('active_storage_attachments.created_at >= ?', Date.current.beginning_of_day)
        .exists?
    end

    def create_check_out
      @check_out = CheckIn.new(
        user: user,
        work_order: work_order,
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
      if user.contractor?
        Notifications::AdminFcmNotificationService.new(
          work_order: work_order,
          notification_type: :check_out,
          title: 'Contractor Check-out',
          message: build_check_out_message(hours_worked),
          metadata: build_check_out_metadata(hours_worked)
        ).call
      else
        Notifications::AdminNotificationService.new(
          work_order: work_order,
          notification_type: :check_out,
          title: 'Contractor Check-out',
          message: build_check_out_message(hours_worked),
          metadata: build_check_out_metadata(hours_worked)
        ).call
      end
    end

    def build_check_out_message(hours_worked)
      "#{user.name || user.email} checked out from #{work_order.name}. " \
        "Hours worked: #{hours_worked}"
    end

    def build_check_out_metadata(hours_worked)
      {
        contractor_id: user.id,
        contractor_name: user.name || user.email,
        check_out_id: check_out.id,
        hours_worked: hours_worked,
        location: build_location_string
      }
    end

    def build_location_string
      return check_out.address if check_out.address.present?
      return "#{latitude}, #{longitude}" if latitude.present? && longitude.present?

      nil
    end
  end
end
