# frozen_string_literal: true

module Avo
  module Resources
    class FreshbooksInvoice < Avo::BaseResource
      self.title = :invoice_number
      self.visible_on_sidebar = false
      self.includes = %i[invoice freshbooks_payments]
      self.search = {
        query: lambda {
          query.ransack(
            freshbooks_id_cont: params[:q],
            invoice_number_cont: params[:q],
            status_cont: params[:q],
            freshbooks_client_id_cont: params[:q],
            m: 'or'
          ).result(distinct: false)
        }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :freshbooks_id, as: :text, required: true, filterable: true
        field :freshbooks_client_id, as: :text, required: true, filterable: true
        field :invoice_number, as: :text, filterable: true
        field :status, as: :text, filterable: true
        field :amount, as: :number
        field :amount_outstanding, as: :number
        field :date, as: :date, filterable: true
        field :due_date, as: :date, filterable: true
        field :currency_code, as: :text, hide_on: [:index]
        field :notes, as: :textarea, hide_on: [:index]
        field :pdf_url, as: :text, hide_on: [:index]
        field :raw_data, as: :code, language: 'json', hide_on: [:index]

        field :invoice, as: :belongs_to, hide_on: [:index]
        field :freshbooks_payments, as: :has_many, hide_on: [:index]

        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
    end
  end
end
