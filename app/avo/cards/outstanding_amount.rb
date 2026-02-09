# frozen_string_literal: true

module Avo
  module Cards
    class OutstandingAmount < Avo::Cards::MetricCard
      self.id = 'outstanding_amount'
      self.label = 'Outstanding amount'
      self.description = 'Total amount of outstanding invoices'
      self.cols = 1
      self.rows = 1
      self.prefix = '£'

      def query
        scope = Invoice.where(is_draft: false)
                       .where.not(final_status: ['paid', 'voided', 'voided + email sent'])
        amount = scope.sum { |inv| (inv.total_amount || 0).to_f }
        result amount.round(2)
      end
    end
  end
end
