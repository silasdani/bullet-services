# frozen_string_literal: true

module Dashboards
  # General contractors (sub-contractors) see all projects and can choose any to check into.
  # Unlike regular contractors, they are not restricted to assigned work orders.
  class GeneralContractorDashboardService < ContractorDashboardService
    private

    def latest_wrs_updated_at
      WindowScheduleRepair
        .where(is_draft: false, deleted_at: nil)
        .contractor_visible_status
        .maximum(:updated_at)
        .to_i
    rescue StandardError => e
      log_error("Error getting latest WRS updated_at: #{e.message}")
      0
    end

    def load_assigned_wrs
      # General contractors see all visible projects (not just assigned)
      WindowScheduleRepair
        .includes(:building, :windows)
        .where(is_draft: false, deleted_at: nil)
        .where.not(building_id: nil)
        .contractor_visible_status
        .order(created_at: :desc)
        .limit(10)
        .map { |wrs| serialize_wrs(wrs) }
    rescue StandardError => e
      log_error("Error loading WRS for general contractor: #{e.message}")
      []
    end
  end
end
