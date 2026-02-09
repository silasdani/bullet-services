# frozen_string_literal: true

module Avo
  module Cards
    class WrsCount < Avo::Cards::MetricCard
      self.id = 'wrs_count'
      self.label = 'WRS (Window Schedule Repairs)'
      self.description = 'Total window schedule repairs'
      self.cols = 1
      self.rows = 1

      def query
        result WindowScheduleRepair.count
      end
    end
  end
end
