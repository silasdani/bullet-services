# frozen_string_literal: true

module RailsAdmin
  module Config
    module Actions
      class CustomDashboard < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :action_name do
          :dashboard
        end

        register_instance_option :root do
          true
        end

        register_instance_option :visible do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            # Outstanding invoices (unpaid, not voided, not draft)
            outstanding_scope = Invoice.where(is_draft: false)
                                       .where.not(final_status: ['paid', 'voided', 'voided + email sent'])

            @outstanding_invoices = outstanding_scope.includes(:freshbooks_invoices)
                                                     .order(created_at: :desc)
                                                     .limit(10)
                                                     .to_a

            # Simple stats
            @outstanding_count = outstanding_scope.count
            @outstanding_amount = outstanding_scope.to_a.sum { |i| (i.total_amount || 0).to_f }

            # Overdue count
            overdue_ids = []
            outstanding_scope.includes(:freshbooks_invoices).each do |invoice|
              freshbooks_invoice = invoice.freshbooks_invoices.first
              overdue_ids << invoice.id if freshbooks_invoice&.due_date && freshbooks_invoice.due_date < Date.current
            end
            @overdue_count = overdue_ids.count
            @overdue_amount = if overdue_ids.any?
                                Invoice.where(id: overdue_ids).to_a.sum do |i|
                                  (i.total_amount || 0).to_f
                                end
                              else
                                0.0
                              end

            # Ensure arrays are never nil
            @outstanding_invoices ||= []

            render template: 'rails_admin/main/dashboard'
          end
        end

        register_instance_option :link_icon do
          'fa fa-dashboard'
        end

        register_instance_option :i18n_key do
          :dashboard
        end
      end
    end
  end
end
