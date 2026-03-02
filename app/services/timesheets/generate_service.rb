# frozen_string_literal: true

module Timesheets
  class GenerateService < ApplicationService
    attribute :user
    attribute :start_date
    attribute :end_date
    attribute :hourly_rate_calculator, default: -> {}

    attr_accessor :timesheet_entries

    def call
      return self if validate_dates.failure?
      return self if generate_entries.failure?

      self
    end

    private

    def validate_dates
      if start_date.blank? || end_date.blank?
        add_error('Start date and end date are required')
      elsif start_date > end_date
        add_error('Start date must be before end date')
      end
      self
    end

    def generate_entries
      entries = find_completed_entries

      @timesheet_entries = entries.map { |entry| build_timesheet_entry(entry) }

      log_info("Generated #{@timesheet_entries.count} timesheet entries")
      self
    end

    def find_completed_entries
      TimeEntry
        .completed
        .where(user: user)
        .where(starts_at: start_date.beginning_of_day..end_date.end_of_day)
        .includes(:work_order)
        .order(starts_at: :asc)
    end

    def build_timesheet_entry(entry)
      hours_worked = entry.duration_hours || 0
      hourly_rate = calculate_hourly_rate(entry)
      total_amount = calculate_total_amount(hours_worked, hourly_rate)

      build_entry_hash(entry, hours_worked, hourly_rate, total_amount)
    end

    def build_entry_hash(entry, hours_worked, hourly_rate, total_amount)
      {
        time_entry_id: entry.id,
        work_order_id: entry.work_order_id,
        work_order_name: entry.work_order&.name,
        date: entry.starts_at.to_date,
        check_in_time: entry.starts_at,
        check_out_time: entry.ends_at,
        hours_worked: hours_worked,
        hours_worked_minutes: (hours_worked * 60).to_i,
        hourly_rate: hourly_rate,
        total_amount: total_amount,
        location: build_location_string(entry)
      }
    end

    def build_location_string(entry)
      entry.end_address.presence || entry.start_address.presence ||
        (entry.end_lat.present? && entry.end_lng.present? ? "#{entry.end_lat}, #{entry.end_lng}" : nil)
    end

    def calculate_hourly_rate(entry)
      return 0 unless hourly_rate_calculator

      hourly_rate_calculator.call(entry)
    rescue StandardError => e
      log_warn("Hourly rate calculation failed: #{e.message}")
      0
    end

    def calculate_total_amount(hours_worked, hourly_rate)
      return 0 unless hourly_rate && hours_worked.positive?

      (hours_worked * hourly_rate).round(2)
    end
  end
end
