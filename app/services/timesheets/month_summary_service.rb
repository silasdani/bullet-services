# frozen_string_literal: true

module Timesheets
  # Returns users who completed at least one work session in the given month,
  # with session count and total hours. Used by Avo Timesheets page.
  class MonthSummaryService < ApplicationService
    attribute :year, default: -> { Time.current.year }
    attribute :month, default: -> { Time.current.month }

    def call
      @result = build_rows
      self
    end

    def rows
      @result || []
    end

    private

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    def build_rows
      return [] unless valid_month?

      ids = TimeEntry.in_month(year, month).distinct.pluck(:user_id)
      return [] if ids.empty?

      users_by_id = User.where(id: ids).index_by(&:id)
      counts = TimeEntry.in_month(year, month).group(:user_id).count
      hours_sql = Arel.sql('EXTRACT(EPOCH FROM (ends_at - starts_at)) / 3600')
      hours_by_id = TimeEntry.in_month(year, month).group(:user_id).sum(hours_sql)

      rows = ids.map do |uid|
        user = users_by_id[uid]
        next unless user

        {
          user: user,
          sessions_count: counts[uid] || 0,
          total_hours: (hours_by_id[uid] || 0).round(2)
        }
      end
      rows.compact.sort_by { |r| r[:user].name.to_s.downcase }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

    def valid_month?
      month.to_i.between?(1, 12) && year.to_i.positive?
    end
  end
end
