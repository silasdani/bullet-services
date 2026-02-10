# frozen_string_literal: true

module WorkSessions
  class CheckInService < ApplicationService
    include AddressResolver
    PROXIMITY_RADIUS_METERS = 50

    attribute :user
    attribute :work_order # Changed from window_schedule_repair
    attribute :latitude
    attribute :longitude
    attribute :address
    attribute :checked_in_at, default: -> { Time.current }

    attr_accessor :work_session

    def call
      return self if validate_active_session.failure?
      return self if validate_contractor_assignment.failure?
      return self if validate_work_order_status.failure?
      return self if validate_proximity.failure?
      return self if create_work_session.failure?

      create_notification
      self
    end

    private

    def validate_active_session
      # Use pessimistic locking to prevent concurrent check-ins
      ActiveRecord::Base.transaction do
        add_error('You already have an active work session. Please check out first.') if active_session_exists?
      end
      self
    end

    def active_session_exists?
      # Only allow ONE active session across all work orders
      WorkSession.active.for_user(user).lock.exists?
    end

    def validate_contractor_assignment
      return self unless user&.contractor?

      building_id = work_order&.building_id
      return self unless building_id

      unless BuildingAssignment.exists?(user_id: user.id, building_id: building_id)
        add_error('You are not assigned to this project. Please assign the project first.')
      end
      self
    end

    def validate_work_order_status
      # Contractors can only check in to approved work orders
      if user.contractor? && work_order.status != 'approved'
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
      building = work_order.building
      building&.latitude && building.longitude && latitude && longitude
    end

    def within_proximity?
      work_order.building.within_radius?(latitude, longitude, PROXIMITY_RADIUS_METERS)
    end

    def add_proximity_errors
      add_error('You must be within 50 meters of the building to check in.')
      distance = work_order.building.distance_to(latitude, longitude)
      add_error("Current distance: #{distance.round(1)} meters. Please move closer.") if distance
    end

    def create_work_session
      @work_session = WorkSession.new(
        user: user,
        work_order: work_order,
        checked_in_at: checked_in_at,
        latitude: latitude,
        longitude: longitude,
        address: resolve_address
      )

      if @work_session.save
        log_info("Work session created: #{@work_session.id}")
      else
        add_errors(@work_session.errors.full_messages)
      end
      self
    end

    # rubocop:disable Metrics/AbcSize
    def create_notification
      if user.contractor?
        log_info("Creating check-in notification for contractor: #{user.email}")
        result = Notifications::AdminFcmNotificationService.new(
          window_schedule_repair: work_order, # Keep for backward compatibility
          notification_type: :check_in,
          title: 'Contractor Check-in',
          message: build_check_in_message,
          metadata: build_check_in_metadata
        ).call
        log_error("Failed to send check-in notification: #{result.errors.join(', ')}") if result.failure?
      else
        log_info("Creating check-in notification for non-contractor: #{user.email}")
        Notifications::AdminNotificationService.new(
          window_schedule_repair: work_order, # Keep for backward compatibility
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
      "#{user.name || user.email} checked in at #{work_order.name}"
    end

    def build_check_in_metadata
      {
        contractor_id: user.id,
        contractor_name: user.name || user.email,
        work_session_id: work_session.id,
        location: work_session.address || "#{latitude}, #{longitude}"
      }
    end
  end
end
