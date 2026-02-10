# frozen_string_literal: true

module Dashboards
  class AdminDashboardService < BaseDashboardService
    def build_dashboard_data
      {
        monthly_stats: calculate_monthly_stats,
        recent_wrs: load_recent_wrs,
        pending_notifications: load_pending_notifications,
        system_health: load_system_health
      }
    end

    private

    # Use counter caches and materialized views for performance
    def calculate_monthly_stats
      Rails.cache.fetch("admin/monthly_stats/#{Date.current.strftime('%Y-%m')}", expires_in: 1.hour) do
        {
          wrs_count: WindowScheduleRepair.where(created_at: month_range).count,
          total_value: WindowScheduleRepair.where(created_at: month_range).sum(:total_vat_included_price) || 0,
          contractors_active: User.contractor.where('updated_at > ?', 30.days.ago).count
        }
      end
    end

    def month_range
      now = Time.current
      start_of_month = now.beginning_of_month
      end_of_month = now.end_of_month
      start_of_month..end_of_month
    end

    def load_recent_wrs
      WindowScheduleRepair
        .includes(:building, :user)
        .order(created_at: :desc)
        .limit(10)
        .map do |wrs|
          {
            id: wrs.id,
            name: wrs.name,
            building_name: wrs.building&.name,
            user_name: wrs.user.name || wrs.user.email,
            status: wrs.status,
            total_vat_included_price: wrs.total_vat_included_price,
            created_at: wrs.created_at
          }
        end
    end

    def load_pending_notifications
      Notification
        .unread
        .where(notification_type: %i[check_in check_out])
        .count
    end

    def load_system_health
      {
        total_users: User.count,
        total_wrs: WindowScheduleRepair.count,
        total_buildings: Building.count,
        active_work_sessions: count_active_work_sessions
      }
    end

    def count_active_work_sessions
      WorkSession.active.count
    rescue StandardError => e
      log_error("Error counting active work sessions: #{e.message}")
      0
    end
  end
end
