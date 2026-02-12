# frozen_string_literal: true

module Dashboards
  # General contractors (sub-contractors) see all projects and can choose any to check into.
  # Unlike regular contractors, they are not restricted to assigned work orders.
  class GeneralContractorDashboardService < ContractorDashboardService
    private

    def latest_work_order_updated_at
      WorkOrder
        .where(is_draft: false, deleted_at: nil)
        .contractor_visible_status
        .maximum(:updated_at)
        .to_i
    rescue StandardError => e
      log_error("Error getting latest work order updated_at: #{e.message}")
      0
    end

    def load_assigned_work_orders
      # General contractors see all visible projects (not just assigned)
      WorkOrder
        .includes(:building, :windows)
        .where(is_draft: false, deleted_at: nil)
        .where.not(building_id: nil)
        .contractor_visible_status
        .order(created_at: :desc)
        .limit(10)
        .map { |wo| serialize_work_order(wo) }
    rescue StandardError => e
      log_error("Error loading work orders for general contractor: #{e.message}")
      []
    end
  end
end
