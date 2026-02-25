# frozen_string_literal: true

module WorkSessions
  class CheckOutService < ApplicationService
    include AddressResolver
    attribute :user
    attribute :work_order
    attribute :ongoing_work
    attribute :latitude
    attribute :longitude
    attribute :address
    attribute :hourly_rate, default: -> { 0 }
    attribute :checked_out_at, default: -> { Time.current }

    attr_accessor :work_session

    def call
      derive_work_order_from_ongoing_work
      ActiveRecord::Base.transaction do
        return self if validate_active_session.failure?
        return self if validate_photos_uploaded.failure?
        return self if validate_timestamps.failure?
        return self if check_out_session.failure?

        create_notification
        self
      end
    rescue ActiveRecord::RecordInvalid => e
      add_errors(e.record.errors.full_messages)
      self
    end

    def hours_worked
      return 0 unless active_session

      active_session.duration_hours || 0
    end

    private

    def derive_work_order_from_ongoing_work
      self.work_order ||= ongoing_work&.work_order
    end

    def validate_active_session
      add_error('No active work session found. Please check in first.') unless active_session
      self
    end

    def validate_photos_uploaded
      # When checking out via ongoing_work, validate photos on that specific record
      if ongoing_work.present?
        unless ongoing_work.images.attached?
          add_error('Cannot check out. Please upload work photos first.')
          add_error('At least one photo is required to document completed work.')
        end
        return self
      end

      # Legacy path: validate via work_order + date matching
      unless photos_uploaded?
        add_error('Cannot check out. Please upload work photos first.')
        add_error('At least one photo is required to document completed work.')
        return self
      end

      unless photos_from_today?
        add_error('Photos must be uploaded today to check out.')
        return self
      end

      self
    end

    def active_session
      @active_session ||= if ongoing_work.present?
                            ongoing_work.work_sessions.active.for_user(user).first
                          else
                            WorkSession.active.for_user(user).for_work_order(work_order).first
                          end
    end

    def photos_uploaded?
      return false unless active_session

      check_in_date = active_session.checked_in_at.to_date

      OngoingWork
        .where(work_order: work_order, user: user)
        .where('work_date >= ?', check_in_date)
        .joins(:images_attachments)
        .where('active_storage_attachments.created_at >= ?', check_in_date.beginning_of_day)
        .exists?
    end

    def photos_from_today?
      return false unless active_session

      OngoingWork
        .where(work_order: work_order, user: user)
        .where('work_date >= ?', active_session.checked_in_at.to_date)
        .joins(:images_attachments)
        .where('active_storage_attachments.created_at >= ?', Date.current.beginning_of_day)
        .exists?
    end

    def check_out_session
      return self unless active_session

      if active_session.check_out!(
        checked_out_time: checked_out_at,
        latitude: latitude,
        longitude: longitude,
        address: resolve_address
      )
        @work_session = active_session.reload
        log_info("Work session checked out: #{@work_session.id}")
      else
        add_errors(active_session.errors.full_messages)
      end
      self
    end

    def validate_timestamps
      return self unless active_session

      check_out_time = checked_out_at || Time.current
      add_error('Check-out time must be after check-in time') if check_out_time <= active_session.checked_in_at
      self
    end

    def create_notification
      hours_worked = self.hours_worked
      result = Notifications::AdminNotificationService.new(
        work_order: work_order,
        notification_type: :check_out,
        title: 'Contractor Check-out',
        message: build_check_out_message(hours_worked),
        metadata: build_check_out_metadata(hours_worked)
      ).call
      log_error("Failed to send check-out notification: #{result.errors.join(', ')}") if result.failure?
    end

    def build_check_out_message(hours_worked)
      "#{user.name || user.email} checked out from #{work_order.name}. " \
        "Hours worked: #{hours_worked.round(2)}"
    end

    def build_check_out_metadata(hours_worked)
      {
        contractor_id: user.id,
        contractor_name: user.name || user.email,
        work_session_id: work_session&.id,
        ongoing_work_id: ongoing_work&.id,
        hours_worked: hours_worked,
        location: build_location_string
      }
    end

    def build_location_string
      return work_session.address if work_session&.address.present?
      return "#{latitude}, #{longitude}" if latitude.present? && longitude.present?

      nil
    end
  end
end
