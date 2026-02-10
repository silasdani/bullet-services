# frozen_string_literal: true

module Avo
  module Resources
    class User < Avo::BaseResource
      self.title = :email
      self.includes = []
      self.search = {
        query: -> { query.ransack(email_cont: params[:q], name_cont: params[:q], m: 'or').result(distinct: false) }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :name, as: :text, filterable: true
        field :email, as: :text, required: true, filterable: true
        field :role_badge, as: :role_badge_field, only_on: %i[index show], name: 'Role'
        field :role, as: :select, enum: ::User.roles, required: true, filterable: true, hide_on: %i[index show]
        field :blocked, as: :boolean, filterable: true
        field :image, as: :file, is_image: true, hide_on: [:index]
        field :fcm_token, as: :text, hide_on: %i[index show]
        field :window_schedule_repairs, as: :has_many, hide_on: [:index]
        field :ongoing_works, as: :has_many, hide_on: [:index]
        field :check_ins, as: :has_many, hide_on: [:index]
        field :work_sessions, as: :has_many, hide_on: [:index]
        field :notifications, as: :has_many, hide_on: [:index]
        field :assigned_buildings, as: :has_many, through: :building_assignments, hide_on: [:index]
        field :created_at, as: :date_time, readonly: true, sortable: true, filterable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
        field :deleted_at, as: :date_time, hide_on: [:index]
      end
    end
  end
end
