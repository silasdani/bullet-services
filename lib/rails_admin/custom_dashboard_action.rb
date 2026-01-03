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
            # Set all instance variables that the view expects
            # Outstanding invoices scope (unpaid, not voided, not draft)
            outstanding_scope = Invoice.where(is_draft: false)
                                       .where.not(final_status: ['paid', 'voided', 'voided + email sent'])

            # Load outstanding invoices with freshbooks_invoices for display (limit 10)
            @outstanding_invoices = outstanding_scope.includes(:freshbooks_invoices)
                                                     .order(created_at: :desc)
                                                     .limit(10)
                                                     .to_a

            # Calculate outstanding count
            @outstanding_count = outstanding_scope.count

            # Load all outstanding invoices once for calculations
            today = Date.current
            all_outstanding = outstanding_scope.includes(:freshbooks_invoices).to_a

            # Calculate outstanding amount
            @outstanding_amount = all_outstanding.sum { |invoice| (invoice.total_amount || 0).to_f }

            # Calculate overdue invoices
            overdue_invoices = all_outstanding.select do |invoice|
              freshbooks_invoice = invoice.freshbooks_invoices.first
              freshbooks_invoice&.due_date && freshbooks_invoice.due_date < today
            end

            @overdue_count = overdue_invoices.count
            @overdue_amount = overdue_invoices.sum { |invoice| (invoice.total_amount || 0).to_f }

            # Ensure all variables have default values
            @outstanding_invoices ||= []
            @outstanding_count ||= 0
            @outstanding_amount ||= 0.0
            @overdue_count ||= 0
            @overdue_amount ||= 0.0

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
