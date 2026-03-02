# frozen_string_literal: true

module TimeEntries
  class CheckInService < ApplicationService
    include AddressResolver

    PROXIMITY_RADIUS_METERS = 50

    attribute :user
    attribute :work_order
    attribute :ongoing_work
    attribute :latitude
    attribute :longitude
    attribute :address
    attribute :starts_at, default: -> { Time.current }

    attr_accessor :time_entry

    def call
      derive_work_order_from_ongoing_work
      return self if validate_active_entry.failure?
      return self if validate_contractor_assignment.failure?
      return self if validate_work_order_status.failure?
      return self if validate_proximity.failure?
      return self if create_time_entry.failure?

      create_notification
      self
    end

    private

    def derive_work_order_from_ongoing_work
      self.work_order ||= ongoing_work&.work_order
    end

    def validate_active_entry
      ActiveRecord::Base.transaction do
        add_error('You already have an active time entry. Please check out first.') if active_entry_exists?
      end
      self
    end

    def active_entry_exists?
      TimeEntry.clocked_in.for_user(user).lock.exists?
    end

    def validate_contractor_assignment
      return self unless user&.contractor?
      return self unless work_order

      unless Assignment.exists?(user_id: user.id, building_id: work_order.building_id)
        add_error('You are not assigned to this project. Please get assigned to the building first.')
      end
      self
    end

    def validate_work_order_status
      if (user.contractor? || user.general_contractor?) && work_order.status != 'approved'
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
      building&.latitude.present? && building.longitude.present? && latitude.present? && longitude.present?
    end

    def within_proximity?
      work_order.building.within_radius?(latitude, longitude, PROXIMITY_RADIUS_METERS)
    end

    def add_proximity_errors
      add_error('Check-in must be within 50m of the project site.')
      distance = work_order.building.distance_to(latitude, longitude)
      add_error("Current distance: #{distance.round(1)} meters. Please move closer.") if distance
    end

    def create_time_entry
      @time_entry = TimeEntry.new(
        user: user,
        work_order: work_order,
        ongoing_work: ongoing_work,
        starts_at: starts_at,
        start_lat: latitude,
        start_lng: longitude,
        start_address: resolve_address
      )

      if @time_entry.save
        log_info("Time entry created: #{@time_entry.id}")
      else
        add_errors(@time_entry.errors.full_messages)
      end
      self
    end

    def create_notification
      if user.contractor?
        create_contractor_notification
      else
        create_admin_notification
      end
    rescue StandardError => e
      log_error("Exception creating check-in notification: #{e.message}")
      log_error(e.backtrace.join("\n")) if e.backtrace
    end

    def build_check_in_message
      "#{user.name || user.email} checked in at #{work_order.name}"
    end

    def build_check_in_metadata
      {
        contractor_id: user.id,
        contractor_name: user.name || user.email,
        time_entry_id: time_entry.id,
        ongoing_work_id: ongoing_work&.id,
        location: time_entry.start_address || "#{latitude}, #{longitude}"
      }
    end

    def create_admin_notification
      result = Notifications::AdminNotificationService.new(
        work_order: work_order,
        notification_type: :check_in,
        title: 'Contractor Check-in',
        message: build_check_in_message,
        metadata: build_check_in_metadata
      ).call
      log_error("Failed to send check-in notification: #{result.errors.join(', ')}") if result.failure?
    end

    def create_contractor_notification
      target_user = ::NotificationRecipients.contractor_recipient
      return unless target_user

      Notifications::CreateService.new(
        user: target_user,
        work_order: work_order,
        notification_type: :check_in,
        title: 'Contractor Check-in',
        message: build_check_in_message,
        metadata: build_check_in_metadata.merge(delivery: 'contractor_only')
      ).call
    rescue StandardError => e
      log_error("Failed to create contractor check-in notification: #{e.message}")
    end
  end
end
