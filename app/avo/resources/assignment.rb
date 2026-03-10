# frozen_string_literal: true

module Avo
  module Resources
    class Assignment < Avo::BaseResource
      self.title = :display_title
      self.model_class = ::Assignment
      self.includes = %i[user building assigned_by_user]

      def fields
        field :id, as: :id, link_to_resource: true
        field :user, as: :belongs_to, required: true, filterable: true, searchable: true
        field :role_badge, as: :role_badge, only_on: %i[index show], name: 'Role'
        field :role,
              as: :select,
              enum: ::Assignment.roles,
              required: true,
              filterable: true,
              display_with_value: true,
              hide_on: %i[index show],
              help: 'Project role for this user. Defaults to the user\'s global role (admin defaults to Contract Manager).'
        field :building, as: :belongs_to, required: true, filterable: true, searchable: true
        field :assigned_by_user, as: :belongs_to, filterable: true, name: 'Assigned by'
        field :created_at, as: :date_time, readonly: true, sortable: true, filterable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
    end
  end
end
