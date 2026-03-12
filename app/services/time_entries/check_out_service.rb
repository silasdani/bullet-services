# frozen_string_literal: true

module TimeEntries
  class CheckOutService < ApplicationService
    include AddressResolver

    attribute :user
    attribute :work_order
    attribute :ongoing_work
    attribute :latitude
    attribute :longitude
    attribute :address
    attribute :ends_at, default: -> { Time.current }

    attr_accessor :time_entry

    def call
      derive_work_order_from_ongoing_work
      ActiveRecord::Base.transaction do
        return self if validate_active_entry.failure?
        return self if validate_photos_uploaded.failure?
        return self if validate_timestamps.failure?
        return self if check_out_entry.failure?

        create_notification
        self
      end
    rescue ActiveRecord::RecordInvalid => e
      add_errors(e.record.errors.full_messages)
      self
    end

    def hours_worked
      return 0 unless time_entry

      time_entry.duration_hours || 0
    end

    private

    def derive_work_order_from_ongoing_work
      self.work_order ||= ongoing_work&.work_order
    end

    def validate_active_entry
      add_error('No active time entry found. Please check in first.') unless active_entry
      self
    end

    def validate_photos_uploaded
      # Managers and admins can check out without photo requirements.
      if work_order && (user.admin? || ProjectRoleResolver.new(user: user, building: work_order.building_id).manager?)
        return self
      end

      unless photos_ok?
        add_error('Cannot check out. Please upload work photos first.')
        add_error('At least one photo is required to document completed work.')
        return self
      end
      add_error('Photos must be uploaded today to check out.') if ongoing_work.blank? && !photos_from_today?
      self
    end

    def photos_ok?
      if ongoing_work.present?
        # Reload to pick up images attached in a recent PATCH (e.g. from app auto-save).
        ongoing_work.reload
        ongoing_work.images.attached? || photos_uploaded?
      else
        photos_uploaded?
      end
    end

    def active_entry
      @active_entry ||= if ongoing_work.present?
                          TimeEntry.clocked_in.for_user(user).for_ongoing_work(ongoing_work).first
                        else
                          TimeEntry.clocked_in.for_user(user).for_work_order(work_order).first
                        end
    end

    def photos_uploaded?
      return false unless active_entry

      check_in_date = active_entry.starts_at.to_date
      OngoingWork
        .where(work_order: work_order, user: user)
        .where('work_date >= ?', check_in_date)
        .joins(:images_attachments)
        .where('active_storage_attachments.created_at >= ?', check_in_date.beginning_of_day)
        .exists?
    end

    def photos_from_today?
      return false unless active_entry

      OngoingWork
        .where(work_order: work_order, user: user)
        .where('work_date >= ?', active_entry.starts_at.to_date)
        .joins(:images_attachments)
        .where('active_storage_attachments.created_at >= ?', Date.current.beginning_of_day)
        .exists?
    end

    def check_out_entry
      return self unless active_entry

      active_entry.check_out!(
        ends_at_time: ends_at || Time.current,
        latitude: latitude,
        longitude: longitude,
        address: resolve_address
      )
      @time_entry = active_entry.reload
      log_info("Time entry checked out: #{@time_entry.id}")
      self
    end

    def validate_timestamps
      return self unless active_entry

      end_time = ends_at || Time.current
      add_error('Check-out time must be after check-in time') if end_time <= active_entry.starts_at
      self
    end

    def create_notification
      hours_worked = self.hours_worked
      if user.contractor?
        create_contractor_notification(hours_worked)
      else
        create_admin_notification(hours_worked)
      end
    end

    def build_check_out_message(hours_worked)
      "#{user.name || user.email} checked out from #{work_order.name}. Hours worked: #{hours_worked.round(2)}"
    end

    def build_check_out_metadata(hours_worked)
      {
        contractor_id: user.id,
        contractor_name: user.name || user.email,
        time_entry_id: time_entry&.id,
        ongoing_work_id: ongoing_work&.id,
        hours_worked: hours_worked,
        location: check_out_location
      }
    end

    def create_admin_notification(hours_worked)
      result = Notifications::AdminNotificationService.new(
        work_order: work_order,
        notification_type: :check_out,
        title: 'Contractor Check-out',
        message: build_check_out_message(hours_worked),
        metadata: build_check_out_metadata(hours_worked)
      ).call
      log_error("Failed to send check-out notification: #{result.errors.join(', ')}") if result.failure?
    end

    def create_contractor_notification(hours_worked)
      target_user = ::NotificationRecipients.contractor_recipient
      return unless target_user

      Notifications::CreateService.new(
        user: target_user,
        work_order: work_order,
        notification_type: :check_out,
        title: 'Contractor Check-out',
        message: build_check_out_message(hours_worked),
        metadata: build_check_out_metadata(hours_worked).merge(delivery: 'contractor_only')
      ).call
    rescue StandardError => e
      log_error("Failed to create contractor check-out notification: #{e.message}")
    end

    def check_out_location
      return time_entry.end_address if time_entry&.end_address.present?
      return "#{latitude}, #{longitude}" if latitude.present? && longitude.present?

      nil
    end
  end
end
