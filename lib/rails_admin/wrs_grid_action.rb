# frozen_string_literal: true

module RailsAdmin
  module Config
    module Actions
      class WrsGrid < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :action_name do
          :wrs_grid
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
            # Load WRS with eager loading (building, user, windows, tools)
            @wrs_items = WorkOrder.includes(:building, :user, :windows, windows: :tools)
                                  .where(is_archived: false, deleted_at: nil)
                                  .order(created_at: :desc)

            # Calculate statistics
            total_wrs = @wrs_items.count
            status_counts = { approved: 0, rejected: 0, completed: 0, pending: 0, draft: 0 }
            published_count = 0
            total_value = 0

            @wrs_items.each do |wrs|
              # Count by status (draft takes priority)
              if wrs.is_draft
                status_counts[:draft] += 1
              elsif wrs.status == 'approved'
                status_counts[:approved] += 1
              elsif wrs.status == 'rejected'
                status_counts[:rejected] += 1
              elsif wrs.status == 'completed'
                status_counts[:completed] += 1
              else
                status_counts[:pending] += 1
              end

              # Count published
              published_count += 1 if wrs.last_published.present?

              # Sum value
              total_value += wrs.grand_total || wrs.total_vat_included_price || 0
            end

            # Store statistics in instance variables
            @total_wrs = total_wrs
            @status_counts = status_counts
            @published_count = published_count
            @draft_count = status_counts[:draft]
            @total_value = total_value

            render template: 'rails_admin/work_orders/grid'
          end
        end

        register_instance_option :link_icon do
          'fa fa-th'
        end

        register_instance_option :show_in_navigation do
          true
        end

        register_instance_option :navigation_label do
          'Grid Views'
        end

        register_instance_option :breadcrumb_parent do
          [:dashboard]
        end

        register_instance_option :i18n_key do
          :wrs_grid
        end
      end
    end
  end
end
