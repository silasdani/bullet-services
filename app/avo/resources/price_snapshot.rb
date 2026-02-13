# frozen_string_literal: true

module Avo
  module Resources
    class PriceSnapshot < Avo::BaseResource
      self.title = :snapshot_at
      self.includes = %i[work_order]
      self.search = {
        query: lambda {
          query.ransack(priceable_type_cont: params[:q], m: 'or').result(distinct: false)
        }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :work_order, as: :belongs_to, required: true, filterable: true
        field :priceable_type, as: :text, required: true, filterable: true
        field :subtotal, as: :number
        field :vat_rate, as: :number
        field :vat_amount, as: :number
        field :total, as: :number
        field :snapshot_at, as: :date_time, required: true, sortable: true, filterable: true
        field :line_items, as: :code, language: 'json', hide_on: [:index]
        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
        field :deleted_at, as: :date_time, hide_on: [:index]
      end
    end
  end
end
