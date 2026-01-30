# frozen_string_literal: true

module Dashboards
  class ContractorDashboardService < BaseDashboardService
    def build_dashboard_data
      {
        assigned_wrs: load_assigned_wrs,
        active_check_in: load_active_check_in,
        pending_photos: load_pending_photos,
        recent_activity: load_recent_activity
      }
    end

    private

    def load_assigned_wrs
      WindowScheduleRepair
        .includes(:building, :windows, :check_ins)
        .where(user: user)
        .where(is_draft: false)
        .contractor_visible_status
        .order(created_at: :desc)
        .limit(10)
        .map { |wrs| serialize_wrs(wrs) }
    rescue StandardError => e
      log_error("Error loading assigned WRS: #{e.message}")
      []
    end

    def load_active_check_in
      active_check_in = CheckIn.active_for(user, nil).includes(:window_schedule_repair).first
      return nil unless active_check_in

      {
        id: active_check_in.id,
        window_schedule_repair_id: active_check_in.window_schedule_repair_id,
        window_schedule_repair_name: active_check_in.window_schedule_repair&.name || 'Unknown',
        timestamp: active_check_in.timestamp,
        address: active_check_in.address
      }
    rescue StandardError => e
      log_error("Error loading active check-in: #{e.message}")
      nil
    end

    def load_pending_photos
      # Placeholder: frontend can derive from WRS/ongoing_work when needed.
      0
    end

    def load_recent_activity
      CheckIn
        .where(user: user)
        .includes(:window_schedule_repair)
        .order(timestamp: :desc)
        .limit(5)
        .map do |check_in|
          {
            id: check_in.id,
            action: check_in.action,
            window_schedule_repair_name: check_in.window_schedule_repair&.name || 'Unknown',
            timestamp: check_in.timestamp
          }
        end
    rescue StandardError => e
      log_error("Error loading recent activity: #{e.message}")
      []
    end

    def serialize_wrs(wrs)
      build_wrs_hash(wrs)
    rescue StandardError => e
      log_error("Error serializing WRS #{wrs.id}: #{e.message}")
      serialize_wrs_fallback(wrs)
    end

    def build_wrs_hash(wrs)
      {
        id: wrs.id,
        name: wrs.name || 'Unnamed',
        building_name: wrs.building&.name,
        address: wrs.building&.full_address || wrs.address || '',
        status: wrs.status || 'pending',
        windows_count: wrs_windows_count(wrs),
        created_at: wrs.created_at
      }
    end

    def wrs_windows_count(wrs)
      wrs.association(:windows).loaded? ? wrs.windows.size : wrs.windows.count
    end

    def serialize_wrs_fallback(wrs)
      {
        id: wrs.id,
        name: wrs.name || 'Unnamed',
        building_name: nil,
        address: '',
        status: 'pending',
        windows_count: 0,
        created_at: wrs.created_at
      }
    end
  end
end
