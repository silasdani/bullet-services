# frozen_string_literal: true

module Api
  module V1
    class DashboardsController < BaseController
      before_action :authorize_dashboard

      def show
        service = Dashboards::DashboardFactory.build(current_user)
        service.call
        render_dashboard(service)
      rescue StandardError => e
        Rails.logger.error "Dashboard error: #{e.message}"
        Rails.logger.error e.backtrace.first(10).join("\n")
        render_dashboard_error
      end

      private

      def authorize_dashboard
        authorize :dashboard, :show?
      end

      def render_dashboard(service)
        if service.success?
          render_success(data: service.result)
        elsif current_user.contractor? || current_user.general_contractor?
          render_success(data: Dashboards::BaseDashboardService::EMPTY_PAYLOAD.dup)
        else
          render_error(message: 'Failed to load dashboard', details: service.errors)
        end
      end

      def render_dashboard_error
        if current_user.contractor? || current_user.general_contractor?
          render_success(data: Dashboards::BaseDashboardService::EMPTY_PAYLOAD.dup)
        else
          render_error(message: 'Failed to load dashboard', status: :internal_server_error)
        end
      end
    end
  end
end
