# frozen_string_literal: true

module Avo
  module Resources
    class WindowScheduleRepair < Avo::BaseResource
      self.title = :name
      self.includes = %i[user building windows]
      self.search = {
        query: lambda {
          query.ransack(name_cont: params[:q], reference_number_cont: params[:q], m: 'or').result(distinct: false)
        }
      }

      # rubocop:disable Metrics/AbcSize
      def fields
        field :id, as: :id, link_to_resource: true
        field :reference_number, as: :text, required: true, filterable: true
        field :name, as: :text, required: true, filterable: true
        field :slug, as: :text, readonly: true, hide_on: [:index]
        field :building, as: :belongs_to, required: true, filterable: true
        field :user, as: :belongs_to, required: true, filterable: true
        field :status_badge, as: :status_badge, only_on: %i[index show], name: 'Status'
        field :status, as: :select, enum: ::WindowScheduleRepair.statuses, required: true, filterable: true,
                       hide_on: %i[index show]
        field :is_draft, as: :boolean, filterable: true, hide_on: %i[index show]
        field :is_archived, as: :boolean, filterable: true, hide_on: %i[index show]
        field :flat_number, as: :text, hide_on: [:index]
        field :address, as: :text, hide_on: [:index]
        field :total_formatted, as: :text, readonly: true, only_on: %i[index show], name: 'Total' do
          record.total ? "£#{record.total.to_f.round(2)}" : '£0.00'
        end
        field :assigned_users, as: :has_many, through: :work_order_assignments, hide_on: [:index]
        field :windows, as: :has_many, hide_on: [:index]
        field :ongoing_works, as: :has_many, hide_on: [:index]
        field :work_sessions, as: :has_many, hide_on: [:index]
        field :invoices, as: :has_many, hide_on: [:index]
        field :created_at, as: :date_time, readonly: true, sortable: true, filterable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
