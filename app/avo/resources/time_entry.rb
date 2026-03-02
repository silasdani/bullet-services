# frozen_string_literal: true

module Avo
  module Resources
    class TimeEntry < Avo::BaseResource
      self.title = :starts_at
      self.includes = %i[user work_order]
      self.search = {
        query: lambda {
          query.ransack(start_address_cont: params[:q], end_address_cont: params[:q], m: 'or').result(distinct: false)
        }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :user, as: :belongs_to, required: true, filterable: true
        field :user_status_badge, as: :user_status_badge, association: :user, only_on: %i[index show],
                                  name: 'User Status'
        field :work_order, as: :belongs_to, required: true, filterable: true
        field :starts_at, as: :date_time, required: true, sortable: true, filterable: true
        field :ends_at, as: :date_time, sortable: true, filterable: true
        field :start_address, as: :text, hide_on: [:index]
        field :end_address, as: :text, hide_on: [:index]
        field :start_lat, as: :number, hide_on: [:index]
        field :start_lng, as: :number, hide_on: [:index]
        field :end_lat, as: :number, hide_on: [:index]
        field :end_lng, as: :number, hide_on: [:index]
        field :ongoing_work, as: :belongs_to, hide_on: [:index]
        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
    end
  end
end
