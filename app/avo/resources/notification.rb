# frozen_string_literal: true

module Avo
  module Resources
    class Notification < Avo::BaseResource
      self.title = :title
      self.includes = %i[user work_order]
      self.search = {
        query: lambda {
          query.ransack(title_cont: params[:q], message_cont: params[:q], m: 'or').result(distinct: false)
        }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :user, as: :belongs_to, required: true, filterable: true
        field :user_status_badge, as: :user_status_badge, association: :user, only_on: %i[index show],
                                  name: 'User Status'
        field :work_order, as: :belongs_to, filterable: true
        field :notification_type, as: :select, enum: ::Notification.notification_types, required: true, filterable: true
        field :title, as: :text, required: true, filterable: true
        field :message, as: :textarea, hide_on: [:index]
        field :metadata, as: :code, language: 'json', hide_on: [:index]
        field :read_at, as: :date_time, filterable: true
        field :created_at, as: :date_time, readonly: true, sortable: true, filterable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
        field :deleted_at, as: :date_time, hide_on: [:index]
      end
    end
  end
end
