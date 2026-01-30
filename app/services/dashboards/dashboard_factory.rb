# frozen_string_literal: true

module Dashboards
  class DashboardFactory
    REGISTRY = {
      'contractor' => ContractorDashboardService,
      'admin' => AdminDashboardService
      # Future roles can be added here:
      # 'surveyor' => SurveyorDashboardService
    }.freeze

    def self.build(user)
      service_class = REGISTRY[user.role] || ContractorDashboardService
      service_class.new(user: user)
    end
  end
end
