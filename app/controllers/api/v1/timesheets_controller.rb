# frozen_string_literal: true

module Api
  module V1
    class TimesheetsController < Api::V1::BaseController
      # GET /api/v1/timesheets
      def index
        authorize Timesheet

        dates = parse_date_range
        target_user = determine_target_user

        service = generate_timesheet_service(target_user, dates)

        if service.success?
          render_timesheet_success(service, target_user, dates)
        else
          render_timesheet_error(service)
        end
      end

      # GET /api/v1/timesheets/export
      def export
        authorize Timesheet, :export?

        dates = parse_date_range
        target_user = determine_target_user
        format = params[:format] || 'json'

        service = generate_timesheet_service(target_user, dates)

        return render_timesheet_error(service) if service.failure?

        handle_export(format, service, target_user, dates)
      end

      private

      def calculate_summary(entries)
        total_hours = entries.sum { |e| e[:hours_worked] }
        total_amount = entries.sum { |e| e[:total_amount] || 0 }
        total_entries = entries.count

        {
          total_hours: total_hours.round(2),
          total_amount: total_amount.round(2),
          total_entries: total_entries,
          average_hours_per_day: total_entries.positive? ? (total_hours / total_entries).round(2) : 0
        }
      end

      def generate_csv(entries, user, start_date, end_date)
        require 'csv'

        CSV.generate(headers: true) do |csv|
          add_csv_header(csv, user, start_date, end_date)
          add_csv_entries(csv, entries)
          add_csv_summary(csv, entries)
        end
      end

      def parse_date_range
        {
          start: params[:start_date] ? Date.parse(params[:start_date]) : Date.current.beginning_of_month,
          end: params[:end_date] ? Date.parse(params[:end_date]) : Date.current.end_of_month
        }
      end

      def determine_target_user
        return User.find(params[:user_id]) if params[:user_id] && current_user.admin?

        current_user
      end

      def generate_timesheet_service(target_user, dates)
        service = Timesheets::GenerateService.new(
          user: target_user,
          start_date: dates[:start],
          end_date: dates[:end]
        )
        service.call
        service
      end

      def render_timesheet_success(service, target_user, dates)
        render_success(
          data: build_timesheet_data(service, target_user, dates)
        )
      end

      def build_timesheet_data(service, target_user, dates)
        {
          user_id: target_user.id,
          user_name: target_user.name || target_user.email,
          start_date: dates[:start],
          end_date: dates[:end],
          entries: service.timesheet_entries,
          summary: calculate_summary(service.timesheet_entries)
        }
      end

      def render_timesheet_error(service)
        render_error(
          message: 'Failed to generate timesheet',
          details: service.errors
        )
      end

      def handle_export(format, service, target_user, dates)
        case format
        when 'csv'
          send_csv_export(service, target_user, dates)
        when 'json'
          render_json_export(service, target_user, dates)
        else
          render_error(message: 'Invalid format. Use csv or json')
        end
      end

      def send_csv_export(service, target_user, dates)
        filename = "timesheet_#{target_user.id}_#{dates[:start]}_#{dates[:end]}.csv"
        send_data generate_csv(service.timesheet_entries, target_user, dates[:start], dates[:end]),
                  filename: filename,
                  type: 'text/csv'
      end

      def render_json_export(service, target_user, dates)
        render json: build_timesheet_data(service, target_user, dates)
      end

      def add_csv_header(csv, user, start_date, end_date)
        csv << ['Timesheet Export']
        csv << ["User: #{user.name || user.email}"]
        csv << ["Period: #{start_date} to #{end_date}"]
        csv << []
        csv << csv_column_headers
      end

      def csv_column_headers
        ['Date', 'WRS Name', 'Check-in Time', 'Check-out Time', 'Hours Worked',
         'Hourly Rate', 'Total Amount', 'Location']
      end

      def add_csv_entries(csv, entries)
        entries.each do |entry|
          csv << build_csv_row(entry)
        end
      end

      def build_csv_row(entry)
        [
          entry[:date],
          entry[:window_schedule_repair_name],
          entry[:check_in_time],
          entry[:check_out_time],
          entry[:hours_worked],
          entry[:hourly_rate] || 0,
          entry[:total_amount] || 0,
          entry[:location]
        ]
      end

      def add_csv_summary(csv, entries)
        csv << []
        summary = calculate_summary(entries)
        csv << ['Summary']
        csv << ['Total Hours', summary[:total_hours]]
        csv << ['Total Amount', summary[:total_amount]]
        csv << ['Total Entries', summary[:total_entries]]
      end
    end
  end
end
