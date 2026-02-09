# frozen_string_literal: true

module CheckIns
  class CheckInService < ApplicationService
    include AddressResolver
    PROXIMITY_RADIUS_METERS = 50

    attribute :user
    attribute :window_schedule_repair
    attribute :latitude
    attribute :longitude
    attribute :address
    attribute :timestamp, default: -> { Time.current }

    attr_accessor :check_in

    def call
      return self if validate_active_check_in.failure?
      return self if validate_contractor_assignment.failure?
      return self if validate_wrs_status.failure?
      return self if validate_proximity.failure?
      return self if create_check_in.failure?

      create_notification
      self
    end

    private

    def validate_active_check_in
      # Use pessimistic locking to prevent concurrent check-ins
      ActiveRecord::Base.transaction do
        add_error('You already have an active check-in. Please check out first.') if active_check_in_exists?
      end
      self
    end

    def active_check_in_exists?
      # Only allow ONE active check-in across all WRS
      CheckIn.active_for(user, nil).lock.exists?
    end

    def validate_contractor_assignment
      return self unless user&.contractor?

      building_id = window_schedule_repair&.building_id
      return self unless building_id

      unless BuildingAssignment.exists?(user_id: user.id, building_id: building_id)
        add_error('You are not assigned to this project. Please assign the project first.')
      end
      self
    end

    def validate_wrs_status
      # Contractors can only check in to approved WRS
      if user.contractor? && window_schedule_repair.status != 'approved'
        add_error('You can only check in to approved works.')
        return self
      end
      self
    end

    def validate_proximity
      return self unless proximity_checkable?
      return self if within_proximity?

      add_proximity_errors
      self
    end

    def proximity_checkable?
      building = window_schedule_repair.building
      building&.latitude && building.longitude && latitude && longitude
    end

    def within_proximity?
      window_schedule_repair.building.within_radius?(latitude, longitude, PROXIMITY_RADIUS_METERS)
    end

    def add_proximity_errors
      add_error('You must be within 50 meters of the building to check in.')
      distance = window_schedule_repair.building.distance_to(latitude, longitude)
      add_error("Current distance: #{distance.round(1)} meters. Please move closer.") if distance
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

    # rubocop:disable Metrics/AbcSize
    def create_notification
      if user.contractor?
        log_info("Creating check-in notification for contractor: #{user.email}")
        result = Notifications::AdminFcmNotificationService.new(
          window_schedule_repair: window_schedule_repair,
          notification_type: :check_in,
          title: 'Contractor Check-in',
          message: build_check_in_message,
          metadata: build_check_in_metadata
        ).call
        log_error("Failed to send check-in notification: #{result.errors.join(', ')}") if result.failure?
      else
        log_info("Creating check-in notification for non-contractor: #{user.email}")
        Notifications::AdminNotificationService.new(
          window_schedule_repair: window_schedule_repair,
          notification_type: :check_in,
          title: 'Contractor Check-in',
          message: build_check_in_message,
          metadata: build_check_in_metadata
        ).call
      end
    rescue StandardError => e
      log_error("Exception creating check-in notification: #{e.message}")
      log_error(e.backtrace.join("\n")) if e.backtrace
      # Don't fail the check-in if notification fails
    end
    # rubocop:enable Metrics/AbcSize

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
