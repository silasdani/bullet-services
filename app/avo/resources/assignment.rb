# frozen_string_literal: true

module Avo
  module Resources
    class Assignment < Avo::BaseResource
      self.title = :id
      self.model_class = ::Assignment
      self.includes = %i[user building assigned_by_user]

      def fields
        field :id, as: :id, link_to_resource: true
        field :user, as: :belongs_to, required: true, filterable: true
        field :building, as: :belongs_to, required: true, filterable: true
        field :assigned_by_user, as: :belongs_to, filterable: true, name: 'Assigned by'
        field :created_at, as: :date_time, readonly: true, sortable: true, filterable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
    end
  end
end
