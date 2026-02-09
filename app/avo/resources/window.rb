# frozen_string_literal: true

module Avo
  module Resources
    class Window < Avo::BaseResource
      self.title = :location
      self.includes = %i[window_schedule_repair tools]
      self.search = {
        query: -> { query.ransack(location_cont: params[:q], m: 'or').result(distinct: false) }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :location, as: :text, required: true, filterable: true
        field :window_schedule_repair, as: :belongs_to, required: true, filterable: true
        field :tools, as: :has_many, hide_on: [:index]
        field :images, as: :files, is_image: true, hide_on: [:index]
        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
    end
  end
end
