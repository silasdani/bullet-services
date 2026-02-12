# frozen_string_literal: true

module Dashboards
  class DashboardFactory
    REGISTRY = {
      'contractor' => ContractorDashboardService,
      'general_contractor' => GeneralContractorDashboardService,
      'admin' => AdminDashboardService,
      'supervisor' => SupervisorDashboardService
    }.freeze

    def self.build(user)
      service_class = REGISTRY[user.role] || ContractorDashboardService
      service_class.new(user: user)
    end
  end
end
