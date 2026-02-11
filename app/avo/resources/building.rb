# frozen_string_literal: true

module Avo
  module Resources
    class Building < Avo::BaseResource
      self.title = :name
      self.includes = []
      self.search = {
        query: lambda {
          query.ransack(name_cont: params[:q], street_cont: params[:q], city_cont: params[:q],
                        m: 'or').result(distinct: false)
        }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :name, as: :text, required: true, filterable: true
        field :street, as: :text, required: true, filterable: true
        field :city, as: :text, required: true, filterable: true
        field :zipcode, as: :text, filterable: true
        field :country, as: :text, required: true, filterable: true
        field :latitude, as: :number, readonly: true, hide_on: [:index]
        field :longitude, as: :number, readonly: true, hide_on: [:index]
        field :window_schedule_repairs, as: :has_many, hide_on: [:index]
        field :created_at, as: :date_time, readonly: true, sortable: true, filterable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
    end
  end
end
