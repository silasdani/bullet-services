# frozen_string_literal: true

module Dashboards
  class SupervisorDashboardService < BaseDashboardService
    def build_dashboard_data
      {
        my_wrs: load_my_wrs,
        assigned_project_wrs: load_assigned_project_wrs,
        projects_count: load_projects_count,
        recent_activity: load_recent_activity
      }
    end

    def build_fallback_dashboard_data
      {
        my_wrs: [],
        assigned_project_wrs: [],
        projects_count: 0,
        recent_activity: []
      }
    end

    private

    def load_my_wrs
      policy_scope(WindowScheduleRepair)
        .where(user_id: user.id)
        .includes(:building, :windows)
        .order(created_at: :desc)
        .limit(10)
        .map { |wrs| serialize_wrs(wrs) }
    rescue StandardError => e
      log_error("Error loading my WRS: #{e.message}")
      []
    end

    def load_assigned_project_wrs
      assigned_building_ids = WorkOrderAssignment.where(user_id: user.id)
                                                 .joins(:work_order)
                                                 .pluck('work_orders.building_id')
                                                 .uniq
      return [] if assigned_building_ids.blank?

      WindowScheduleRepair
        .where(building_id: assigned_building_ids)
        .where.not(user_id: user.id) # Exclude own WRS (already in my_wrs)
        .includes(:building, :windows)
        .order(created_at: :desc)
        .limit(10)
        .map { |wrs| serialize_wrs(wrs) }
    rescue StandardError => e
      log_error("Error loading assigned project WRS: #{e.message}")
      []
    end

    def load_projects_count
      Building.count
    end

    def load_recent_activity
      []
    end

    def serialize_wrs(wrs)
      {
        id: wrs.id,
        name: wrs.name || 'Unnamed',
        building_name: wrs.building&.name,
        address: wrs.building&.full_address || '',
        status: wrs.status || 'pending',
        windows_count: wrs.association(:windows).loaded? ? wrs.windows.size : wrs.windows.count,
        created_at: wrs.created_at,
        is_mine: wrs.user_id == user.id
      }
    end

    def policy_scope(scope)
      Pundit.policy_scope!(user, scope)
    end

    def latest_wrs_updated_at
      assigned_building_ids = WorkOrderAssignment.where(user_id: user.id)
                                                 .joins(:work_order)
                                                 .pluck('work_orders.building_id')
                                                 .uniq
      base = WindowScheduleRepair.where(user_id: user.id)
      base = base.or(WindowScheduleRepair.where(building_id: assigned_building_ids)) if assigned_building_ids.any?
      base.maximum(:updated_at).to_i
    rescue StandardError => e
      log_error("Error getting latest WRS updated_at: #{e.message}")
      0
    end
  end
end
