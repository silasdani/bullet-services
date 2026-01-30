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
        active_check_ins: count_active_check_ins
      }
    end

    def count_active_check_ins
      # Count all active check-ins (check-ins without corresponding check-outs)
      # Use raw SQL to avoid enum loading issues with Rails 8
      # action: 0 = check_in, 1 = check_out
      # Query check-ins that don't have a corresponding check-out for the same user/WRS
      sql = <<-SQL.squish
        SELECT COUNT(DISTINCT ci1.id) as count
        FROM check_ins ci1
        WHERE ci1.action = 0
        AND NOT EXISTS (
          SELECT 1 FROM check_ins ci2
          WHERE ci2.user_id = ci1.user_id
          AND ci2.window_schedule_repair_id = ci1.window_schedule_repair_id
          AND ci2.action = 1
          AND ci2.id > ci1.id
        )
      SQL
      result = ActiveRecord::Base.connection.execute(sql)
      # PostgreSQL returns hash with string keys, SQLite might return array
      count = result.is_a?(Array) ? result.first&.first : result.first&.dig('count')
      count.to_i
    rescue StandardError => e
      log_error("Error counting active check-ins: #{e.message}")
      0
    end
  end
end
