# frozen_string_literal: true

module Dashboards
  class SupervisorDashboardService < BaseDashboardService
    def build_dashboard_data
      {
        my_work_orders: load_my_work_orders,
        assigned_project_work_orders: load_assigned_project_work_orders,
        projects_count: load_projects_count,
        recent_activity: load_recent_activity
      }
    end

    def build_fallback_dashboard_data
      {
        my_work_orders: [],
        assigned_project_work_orders: [],
        projects_count: 0,
        recent_activity: []
      }
    end

    private

    def load_my_work_orders
      policy_scope(WorkOrder)
        .where(user_id: user.id)
        .includes(:building, :windows)
        .order(created_at: :desc)
        .limit(10)
        .map { |work_order| serialize_work_order(work_order) }
    rescue StandardError => e
      log_error("Error loading my work orders: #{e.message}")
      []
    end

    def load_assigned_project_work_orders
      building_ids = assigned_project_building_ids
      return [] if building_ids.blank?

      fetch_project_work_orders(building_ids)
    rescue StandardError => e
      log_error("Error loading assigned project work orders: #{e.message}")
      []
    end

    def assigned_project_building_ids
      WorkOrderAssignment.where(user_id: user.id)
                         .joins(:work_order)
                         .pluck('work_orders.building_id')
                         .uniq
    end

    def fetch_project_work_orders(building_ids)
      WorkOrder
        .where(building_id: building_ids)
        .where.not(user_id: user.id)
        .includes(:building, :windows)
        .order(created_at: :desc)
        .limit(10)
        .map { |work_order| serialize_work_order(work_order) }
    end

    def load_projects_count
      Building.count
    end

    def load_recent_activity
      []
    end

    def serialize_work_order(work_order)
      building = work_order.building
      {
        id: work_order.id,
        name: work_order.name || 'Unnamed',
        building_name: building&.name,
        address: building&.full_address || '',
        status: work_order.status || 'pending',
        windows_count: work_order_windows_count(work_order),
        created_at: work_order.created_at,
        is_mine: work_order.user_id == user.id
      }
    end

    def work_order_windows_count(work_order)
      work_order.association(:windows).loaded? ? work_order.windows.size : work_order.windows.count
    end

    def policy_scope(scope)
      Pundit.policy_scope!(user, scope)
    end

    def latest_work_order_updated_at
      assigned_building_ids = WorkOrderAssignment.where(user_id: user.id)
                                                 .joins(:work_order)
                                                 .pluck('work_orders.building_id')
                                                 .uniq
      base = WorkOrder.where(user_id: user.id)
      base = base.or(WorkOrder.where(building_id: assigned_building_ids)) if assigned_building_ids.any?
      base.maximum(:updated_at).to_i
    rescue StandardError => e
      log_error("Error getting latest work order updated_at: #{e.message}")
      0
    end
  end
end
