# frozen_string_literal: true

module Avo
  module Fields
    class InvoiceStatusBadgeField < Avo::Fields::BaseField
      def value
        return nil unless record

        record.final_status || record.status
      end
    end
  end
end
