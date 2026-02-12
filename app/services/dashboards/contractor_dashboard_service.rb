# frozen_string_literal: true

module Dashboards
  class ContractorDashboardService < BaseDashboardService
    def build_dashboard_data
      {
        assigned_work_orders: load_assigned_work_orders,
        active_work_session: load_active_work_session,
        pending_photos: load_pending_photos,
        recent_activity: load_recent_activity
      }
    end

    private

    def load_assigned_work_orders
      WorkOrder
        .includes(:building, :windows)
        .where(user: user)
        .where(is_draft: false)
        .contractor_visible_status
        .order(created_at: :desc)
        .limit(10)
        .map { |wo| serialize_work_order(wo) }
    rescue StandardError => e
      log_error("Error loading assigned work orders: #{e.message}")
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

    def serialize_work_order(wo)
      build_work_order_hash(wo)
    rescue StandardError => e
      log_error("Error serializing work order #{wo.id}: #{e.message}")
      serialize_work_order_fallback(wo)
    end

    def build_work_order_hash(wo)
      {
        id: wo.id,
        name: wo.name || 'Unnamed',
        building_name: wo.building&.name,
        address: wo.building&.full_address || wo.address || '',
        status: wo.status || 'pending',
        windows_count: work_order_windows_count(wo),
        created_at: wo.created_at
      }
    end

    def work_order_windows_count(wo)
      wo.association(:windows).loaded? ? wo.windows.size : wo.windows.count
    end

    def serialize_work_order_fallback(wo)
      {
        id: wo.id,
        name: wo.name || 'Unnamed',
        building_name: nil,
        address: '',
        status: 'pending',
        windows_count: 0,
        created_at: wo.created_at
      }
    end
  end
end
