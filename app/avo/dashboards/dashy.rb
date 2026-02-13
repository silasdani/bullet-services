# frozen_string_literal: true

module Avo
  module Dashboards
    class Dashy < Avo::Dashboards::BaseDashboard
      self.id = 'dashy'
      self.name = 'Dashboard'
      self.description = 'Overview of users, work orders, and invoices'
      self.grid_cols = 3

      def cards
        card Avo::Cards::UsersCount
        card Avo::Cards::WorkOrderCount
        card Avo::Cards::OngoingWorksCount

        divider label: 'Invoices'
        card Avo::Cards::OutstandingInvoicesCount
        card Avo::Cards::OutstandingAmount
        card Avo::Cards::OverdueInvoicesCount
        card Avo::Cards::OverdueAmount
      end
    end
  end
end
