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
        amount = outstanding.sum do |invoice|
          fb_invoice = invoice.primary_freshbooks_invoice
          next 0 unless fb_invoice&.due_date && fb_invoice.due_date < today

          outstanding_amount = fb_invoice.amount_outstanding
          (outstanding_amount.nil? ? invoice.total_amount : outstanding_amount).to_f
        end
        result amount.round(2)
      end
    end
  end
end
