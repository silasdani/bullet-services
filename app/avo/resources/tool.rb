# frozen_string_literal: true

module Avo
  module Resources
    class Tool < Avo::BaseResource
      self.title = :name
      self.includes = [:window]
      self.search = {
        query: -> { query.ransack(name_cont: params[:q], m: 'or').result(distinct: false) }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :name, as: :select, options: lambda {
          Tool.common_tool_names.index_by(&:itself)
        }, required: true, filterable: true, html: {
          data: {
            controller: 'tool-price'
          }
        }
        field :price_formatted, as: :text, readonly: true, only_on: %i[index show], name: 'Price' do
          record.price ? "£#{record.price.to_f.round(2)}" : '£0.00'
        end
        field :price, as: :number, required: true, filterable: true, hide_on: %i[index show]
        field :window, as: :belongs_to, required: true, filterable: true
        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
    end
  end
end
