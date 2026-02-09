# frozen_string_literal: true

module Avo
  module Fields
    class StatusBadgeField < Avo::Fields::BaseField
      def value
        return nil unless record

        record.status
      end
    end
  end
end
