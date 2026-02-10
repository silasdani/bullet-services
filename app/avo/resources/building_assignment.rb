# frozen_string_literal: true

module Avo
  module Resources
    class BuildingAssignment < Avo::BaseResource
      self.title = :id
      self.includes = %i[user building assigned_by_user]
      self.search = {
        query: -> { query.ransack(m: "or").result(distinct: false) }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :user, as: :belongs_to, required: true, filterable: true
        field :building, as: :belongs_to, required: true, filterable: true
        field :assigned_by_user, as: :belongs_to, hide_on: [:index]
        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
        field :deleted_at, as: :date_time, hide_on: [:index]
      end
    end
  end
end

