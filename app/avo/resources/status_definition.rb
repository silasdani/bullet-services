# frozen_string_literal: true

module Avo
  module Resources
    class StatusDefinition < Avo::BaseResource
      self.title = :status_label
      self.includes = []
      self.search = {
        query: lambda {
          query.ransack(entity_type_cont: params[:q], status_key_cont: params[:q], status_label_cont: params[:q],
                        m: 'or')
               .result(distinct: false)
        }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :entity_type, as: :text, required: true, filterable: true
        field :status_key, as: :text, required: true, filterable: true
        field :status_label, as: :text, required: true, filterable: true
        field :status_color, as: :text, required: true, filterable: true
        field :display_order, as: :number, filterable: true
        field :is_active, as: :boolean, filterable: true
        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
    end
  end
end
