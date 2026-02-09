# frozen_string_literal: true

module Avo
  module Cards
    class OngoingWorksCount < Avo::Cards::MetricCard
      self.id = 'ongoing_works_count'
      self.label = 'Ongoing works'
      self.description = 'Total ongoing work records'
      self.cols = 1
      self.rows = 1

      def query
        result OngoingWork.count
      end
    end
  end
end
