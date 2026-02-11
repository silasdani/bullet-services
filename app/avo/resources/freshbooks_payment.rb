# frozen_string_literal: true

module Avo
  module Resources
    class FreshbooksPayment < Avo::BaseResource
      self.title = :freshbooks_id
      self.includes = %i[freshbooks_invoice]
      self.search = {
        query: lambda {
          query.ransack(
            freshbooks_id_cont: params[:q],
            freshbooks_invoice_id_cont: params[:q],
            payment_method_cont: params[:q],
            currency_code_cont: params[:q],
            m: 'or'
          ).result(distinct: false)
        }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :freshbooks_id, as: :text, required: true, filterable: true
        field :freshbooks_invoice_id, as: :text, required: true, filterable: true
        field :amount, as: :number, required: true
        field :date, as: :date, required: true, filterable: true
        field :payment_method, as: :text, hide_on: [:index]
        field :currency_code, as: :text, hide_on: [:index]
        field :notes, as: :textarea, hide_on: [:index]
        field :raw_data, as: :code, language: 'json', hide_on: [:index]

        field :freshbooks_invoice, as: :belongs_to, hide_on: [:index]

        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
    end
  end
end
