# frozen_string_literal: true

module Avo
  module Cards
    class WorkOrderCount < Avo::Cards::MetricCard
      self.id = 'work_order_count'
      self.label = 'Work Orders'
      self.description = 'Total work orders'
      self.cols = 1
      self.rows = 1

      def query
        result WorkOrder.count
      end
    end
  end
end
