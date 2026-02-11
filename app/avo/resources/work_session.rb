# frozen_string_literal: true

module Avo
  module Resources
    class WorkSession < Avo::BaseResource
      self.title = :checked_in_at
      self.includes = %i[user work_order]
      self.search = {
        query: lambda {
          query.ransack(address_cont: params[:q], m: 'or').result(distinct: false)
        }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :user, as: :belongs_to, required: true, filterable: true
        field :work_order, as: :belongs_to, required: true, filterable: true
        field :checked_in_at, as: :date_time, required: true, sortable: true, filterable: true
        field :checked_out_at, as: :date_time, sortable: true, filterable: true
        field :address, as: :text, hide_on: [:index]
        field :latitude, as: :number, hide_on: [:index]
        field :longitude, as: :number, hide_on: [:index]
        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
        field :deleted_at, as: :date_time, hide_on: [:index]
      end
    end
  end
end
