# frozen_string_literal: true

module Avo
  module Cards
    class OutstandingInvoicesCount < Avo::Cards::MetricCard
      self.id = 'outstanding_invoices_count'
      self.label = 'Outstanding invoices'
      self.description = 'Invoices not paid, voided, or draft'
      self.cols = 1
      self.rows = 1

      def query
        scope = Invoice.where(is_draft: false)
                       .where.not(final_status: ['paid', 'voided', 'voided + email sent'])
        result scope.count
      end
    end
  end
end
