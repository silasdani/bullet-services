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
                       .includes(:freshbooks_invoices)

        amount = scope.sum do |invoice|
          fb_invoice = invoice.primary_freshbooks_invoice
          outstanding = fb_invoice&.amount_outstanding

          (outstanding.nil? ? invoice.total_amount : outstanding).to_f
        end

        result amount.round(2)
      end
    end
  end
end
