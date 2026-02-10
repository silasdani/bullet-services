# frozen_string_literal: true

module Avo
  module Resources
    class FreshbooksClient < Avo::BaseResource
      self.title = :freshbooks_id
      self.includes = %i[freshbooks_invoices]
      self.search = {
        query: lambda {
          query.ransack(
            freshbooks_id_cont: params[:q],
            email_cont: params[:q],
            first_name_cont: params[:q],
            last_name_cont: params[:q],
            organization_cont: params[:q],
            m: "or"
          ).result(distinct: false)
        }
      }

      def fields
        field :id, as: :id, link_to_resource: true
        field :freshbooks_id, as: :text, filterable: true
        field :email, as: :text, filterable: true
        field :first_name, as: :text, hide_on: [:index]
        field :last_name, as: :text, hide_on: [:index]
        field :organization, as: :text, filterable: true
        field :phone, as: :text, hide_on: [:index]
        field :address, as: :textarea, hide_on: [:index]
        field :city, as: :text, hide_on: [:index]
        field :province, as: :text, hide_on: [:index]
        field :postal_code, as: :text, hide_on: [:index]
        field :country, as: :text, hide_on: [:index]
        field :raw_data, as: :code, language: "json", hide_on: [:index]
        field :freshbooks_invoices, as: :has_many, hide_on: [:index]
        field :created_at, as: :date_time, readonly: true, sortable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
    end
  end
end

