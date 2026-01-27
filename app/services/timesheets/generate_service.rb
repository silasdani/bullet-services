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
      check_in_pairs = find_check_in_pairs

      @timesheet_entries = check_in_pairs.map do |check_in, check_out|
        build_timesheet_entry(check_in, check_out)
      end

      log_info("Generated #{@timesheet_entries.count} timesheet entries")
      self
    end

    def find_check_in_pairs
      check_ins = CheckIn.where(user: user, action: :check_in)
                         .where('timestamp >= ? AND timestamp <= ?', start_date.beginning_of_day, end_date.end_of_day)
                         .order(timestamp: :asc)

      pairs = []
      check_ins.each do |check_in|
        check_out = find_matching_check_out(check_in)
        pairs << [check_in, check_out] if check_out
      end

      pairs
    end

    def find_matching_check_out(check_in)
      CheckIn.where(
        user: user,
        window_schedule_repair: check_in.window_schedule_repair,
        action: :check_out
      ).where('timestamp > ?', check_in.timestamp)
             .order(timestamp: :asc)
             .first
    end

    def build_timesheet_entry(check_in, check_out)
      hours_worked = calculate_hours_worked(check_in.timestamp, check_out.timestamp)
      hourly_rate = calculate_hourly_rate(check_in, check_out)
      total_amount = calculate_total_amount(hours_worked, hourly_rate)

      build_entry_hash(check_in, check_out, hours_worked, hourly_rate, total_amount)
    end

    def build_entry_hash(check_in, check_out, hours_worked, hourly_rate, total_amount)
      {
        check_in_id: check_in.id,
        check_out_id: check_out.id,
        window_schedule_repair_id: check_in.window_schedule_repair_id,
        window_schedule_repair_name: check_in.window_schedule_repair.name,
        date: check_in.timestamp.to_date,
        check_in_time: check_in.timestamp,
        check_out_time: check_out.timestamp,
        hours_worked: hours_worked,
        hours_worked_minutes: (hours_worked * 60).to_i,
        hourly_rate: hourly_rate,
        total_amount: total_amount,
        location: build_location_string(check_in)
      }
    end

    def build_location_string(check_in)
      check_in.address || "#{check_in.latitude}, #{check_in.longitude}"
    end

    def calculate_hours_worked(check_in_time, check_out_time)
      return 0 unless check_in_time && check_out_time

      duration_seconds = check_out_time - check_in_time
      (duration_seconds / 1.hour).round(2)
    end

    def calculate_hourly_rate(check_in, check_out)
      return 0 unless hourly_rate_calculator

      hourly_rate_calculator.call(check_in, check_out)
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
