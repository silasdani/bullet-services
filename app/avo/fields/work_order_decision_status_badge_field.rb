# frozen_string_literal: true

module Avo
  module Fields
    class WorkOrderDecisionStatusBadgeField < Avo::Fields::BaseField
      def value
        return nil unless record

        record.decision
      end
    end
  end
end

