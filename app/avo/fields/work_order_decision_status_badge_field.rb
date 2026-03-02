# frozen_string_literal: true

module Avo
  module Fields
    class WorkOrderDecisionStatusBadgeField < Avo::Fields::BaseField
      def value
        return nil unless record

        decision_record = record.is_a?(::Decision) ? record : record.try(:decision)
        decision_record&.decision
      end
    end
  end
end
