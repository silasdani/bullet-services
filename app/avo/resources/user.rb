# frozen_string_literal: true

module Avo
  module Resources
    class User < Avo::BaseResource
      self.title = :email
      self.includes = []
      self.record_selector = false
      self.search = {
        query: lambda {
          query.ransack(
            email_cont: params[:q],
            first_name_cont: params[:q],
            last_name_cont: params[:q],
            m: 'or'
          ).result(distinct: false)
        }
      }

      # rubocop:disable Metrics/MethodLength
      def fields
        field :id, as: :id, link_to_resource: true
        field :email, as: :text, required: true, filterable: true
        field :status_badge, as: :user_status_badge, only_on: %i[index show], name: 'Status'
        field :first_name, as: :text, required: true, filterable: true
        field :last_name, as: :text, required: true, filterable: true
        field :phone_no, as: :text, filterable: true
        field :password,
              as: :password,
              hide_on: %i[index show],
              required: -> { view.new? }
        field :password_confirmation,
              as: :password,
              hide_on: %i[index show],
              required: -> { view.new? }
        field :role, as: :select, enum: ::User.roles, required: true, filterable: true, hide_on: %i[index show]
        field :blocked, as: :boolean, filterable: true
        field :image, as: :file, is_image: true, hide_on: [:index]
        field :fcm_token, as: :text, hide_on: %i[index show]
        field :work_orders, as: :has_many, hide_on: [:index]
        field :ongoing_works, as: :has_many, hide_on: [:index]
        field :check_ins, as: :has_many, hide_on: [:index]
        field :time_entries, as: :has_many, hide_on: [:index]
        field :notifications, as: :has_many, hide_on: [:index]
        field :assignments, as: :has_many, hide_on: [:index]
        field :assigned_buildings, as: :has_many, through: :assignments, hide_on: [:index]
        field :created_at, as: :date_time, readonly: true, sortable: true, filterable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
        field :deleted_at, as: :date_time, hide_on: [:index]
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
