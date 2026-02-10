# frozen_string_literal: true

module Dashboards
  class ContractorDashboardService < BaseDashboardService
    def build_dashboard_data
      {
        assigned_wrs: load_assigned_wrs,
        active_work_session: load_active_work_session,
        pending_photos: load_pending_photos,
        recent_activity: load_recent_activity
      }
    end

    private

    def load_assigned_wrs
      WindowScheduleRepair
        .includes(:building, :windows)
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

    def load_active_work_session
      session = WorkSession.active.for_user(user).includes(:work_order).first
      return nil unless session

      {
        id: session.id,
        work_order_id: session.work_order_id,
        work_order_name: session.work_order&.name || 'Unknown',
        checked_in_at: session.checked_in_at,
        address: session.address
      }
    rescue StandardError => e
      log_error("Error loading active work session: #{e.message}")
      nil
    end

    def load_pending_photos
      # Placeholder: frontend can derive from WRS/ongoing_work when needed.
      0
    end

    def load_recent_activity
      WorkSession
        .where(user: user)
        .includes(:work_order)
        .order(checked_in_at: :desc)
        .limit(5)
        .map do |session|
          {
            id: session.id,
            work_order_name: session.work_order&.name || 'Unknown',
            checked_in_at: session.checked_in_at,
            checked_out_at: session.checked_out_at,
            active: session.active?
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
