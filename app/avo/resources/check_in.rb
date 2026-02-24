# frozen_string_literal: true

module Avo
  module Resources
    class CheckIn < Avo::BaseResource
      self.title = :id
      self.includes = %i[user work_order]
      self.visible_on_sidebar = false
      self.search = {
        query: -> { query.ransack(id_eq: params[:q], address_cont: params[:q], m: 'or').result(distinct: false) }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :user, as: :belongs_to, required: true, filterable: true
        field :user_status_badge, as: :user_status_badge, association: :user, only_on: %i[index show],
                                  name: 'User Status'
        field :work_order, as: :belongs_to, required: true, filterable: true
        field :action, as: :select, enum: ::CheckIn.actions, required: true, filterable: true
        field :timestamp, as: :date_time, required: true, sortable: true, filterable: true
        field :address, as: :text, hide_on: [:index]
        field :latitude, as: :number, hide_on: [:index]
        field :longitude, as: :number, hide_on: [:index]
        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
    end
  end
end
