# frozen_string_literal: true

module Dashboards
  class BaseDashboardService < ApplicationService
    attribute :user

    attr_accessor :result

    # Single source for empty/fallback contractor dashboard payload.
    EMPTY_PAYLOAD = {
      assigned_wrs: [],
      active_work_session: nil,
      pending_photos: 0,
      recent_activity: []
    }.freeze

    def call
      @result = Rails.cache.fetch(cache_key, expires_in: 5.minutes) { build_dashboard_data }
      self
    rescue StandardError => e
      log_error("Error building dashboard: #{e.message}")
      log_error(e.backtrace.first(10).join("\n"))
      @result = build_fallback_dashboard_data
      add_error('Failed to load some dashboard data')
      self
    end

    private

    def cache_key
      "dashboard/#{user.id}/#{user.role}/#{cache_version}"
    end

    def cache_version
      [user.updated_at.to_i, latest_wrs_updated_at].max
    end

    def latest_wrs_updated_at
      WindowScheduleRepair.where(user: user).maximum(:updated_at).to_i
    rescue StandardError => e
      log_error("Error getting latest WRS updated_at: #{e.message}")
      0
    end

    def build_dashboard_data
      raise NotImplementedError, 'Subclasses must implement #build_dashboard_data'
    end

    def build_fallback_dashboard_data
      EMPTY_PAYLOAD.dup
    end
  end
end
