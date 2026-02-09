# frozen_string_literal: true

module Avo
  module Cards
    class OverdueInvoicesCount < Avo::Cards::MetricCard
      self.id = 'overdue_invoices_count'
      self.label = 'Overdue invoices'
      self.description = 'Outstanding invoices past due date'
      self.cols = 1
      self.rows = 1

      def query
        today = Date.current
        outstanding = Invoice.where(is_draft: false)
                             .where.not(final_status: ['paid', 'voided', 'voided + email sent'])
                             .includes(:freshbooks_invoices)
        count = outstanding.count do |inv|
          fb = inv.freshbooks_invoices.first
          fb&.due_date && fb.due_date < today
        end
        result count
      end
    end
  end
end
