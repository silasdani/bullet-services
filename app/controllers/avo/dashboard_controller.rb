# frozen_string_literal: true

# Custom dashboard page when avo-dashboards (Pro) plugin is not installed.
# Renders the same metrics as app/avo/dashboards/dashy.rb so /avo has a landing page.
module Avo
  class DashboardController < Avo::ApplicationController
    layout 'avo/application'

    def index
      @resource = nil
      @page_title = 'Dashboard'
      @metrics = {
        users_count: User.count,
        work_orders_count: WorkOrder.count,
        ongoing_works_count: OngoingWork.count,
        outstanding_invoices_count: outstanding_scope.count,
        outstanding_amount: outstanding_scope.sum { |inv| (inv.total_amount || 0).to_f }.round(2),
        overdue_invoices_count: overdue_count,
        overdue_amount: overdue_amount.round(2)
      }
    end

    private

    def outstanding_scope
      @outstanding_scope ||= Invoice.where(is_draft: false)
                                    .where.not(final_status: ['paid', 'voided', 'voided + email sent'])
    end

    def overdue_count
      today = Date.current
      outstanding_scope.includes(:freshbooks_invoices).count do |inv|
        fb = inv.freshbooks_invoices.first
        fb&.due_date && fb.due_date < today
      end
    end

    def overdue_amount
      today = Date.current
      outstanding_scope.includes(:freshbooks_invoices).sum do |inv|
        fb = inv.freshbooks_invoices.first
        next 0 unless fb&.due_date && fb.due_date < today

        (inv.total_amount || 0).to_f
      end
    end
  end
end
