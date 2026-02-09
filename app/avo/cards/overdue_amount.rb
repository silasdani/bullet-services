# frozen_string_literal: true

module Avo
  module Cards
    class OverdueAmount < Avo::Cards::MetricCard
      self.id = 'overdue_amount'
      self.label = 'Overdue amount'
      self.description = 'Total amount of overdue invoices'
      self.cols = 1
      self.rows = 1
      self.prefix = '£'

      def query
        today = Date.current
        outstanding = Invoice.where(is_draft: false)
                             .where.not(final_status: ['paid', 'voided', 'voided + email sent'])
                             .includes(:freshbooks_invoices)
        amount = outstanding.sum do |inv|
          fb = inv.freshbooks_invoices.first
          fb&.due_date && fb.due_date < today ? (inv.total_amount || 0).to_f : 0
        end
        result amount.round(2)
      end
    end
  end
end
