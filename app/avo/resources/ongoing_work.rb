# frozen_string_literal: true

module Avo
  module Resources
    class OngoingWork < Avo::BaseResource
      self.title = :id
      self.includes = [:work_order, :user, { work_order: %i[building windows] }]
      self.default_view_type = :table
      self.search = {
        query: -> { query.ransack(id_eq: params[:q], description_cont: params[:q], m: 'or').result(distinct: false) }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :work_date, as: :date, required: true, sortable: true, filterable: true
        field :work_order, as: :belongs_to, required: true, filterable: true
        field :user, as: :belongs_to, required: true, name: 'Contractor', filterable: true
        field :user_status_badge, as: :user_status_badge, association: :user, only_on: %i[index show],
                                  name: 'User Status'
        field :images_count, as: :text, name: 'Images', only_on: [:index] do
          count = record.images.count
          count.positive? ? "#{count} #{'image'.pluralize(count)}" : 'No images'
        end
        field :description, as: :textarea, hide_on: [:index]
        field :images_with_windows, as: :windows_info_field, name: 'Images (by window)', only_on: %i[show edit]
        field :images, as: :files, is_image: true, hide_on: [:index], name: 'Upload images'
        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
    end
  end
end
