# frozen_string_literal: true

module Avo
  module Resources
    class Invoice < Avo::BaseResource
      STATUS_OPTIONS = { draft: 'draft', sent: 'sent', viewed: 'viewed', paid: 'paid', voided: 'voided' }.freeze

      self.title = :name
      self.includes = [:work_order]
      self.search = {
        query: lambda {
          query.ransack(name_cont: params[:q], slug_cont: params[:q], flat_address_cont: params[:q],
                        m: 'or').result(distinct: false)
        }
      }

      # rubocop:disable Metrics/AbcSize
      def fields
        field :id, as: :id, link_to_resource: true
        field :name, as: :text, required: true, filterable: true
        field :slug, as: :text, readonly: true, hide_on: [:index]
        field :status_badge, as: :invoice_status_badge, only_on: %i[index show], name: 'Status'
        field :final_status, as: :select,
                             options: STATUS_OPTIONS, required: true, filterable: true, hide_on: %i[index show]
        field :status, as: :select,
                       options: STATUS_OPTIONS, required: true, hide_on: %i[index show]
        field :work_order, as: :belongs_to, filterable: true
        field :total_amount, as: :text, readonly: true, only_on: %i[index show] do
          amount = record.total_amount
          amount ? "£#{amount.to_f.round(2)}" : '£0.00'
        end
        field :included_vat_amount, as: :number, hide_on: [:index]
        field :excluded_vat_amount, as: :number, hide_on: [:index]
        field :is_draft, as: :boolean, filterable: true, hide_on: %i[index show]
        field :is_archived, as: :boolean, filterable: true, hide_on: %i[index show]
        field :invoice_pdf, as: :file, accept: 'application/pdf', hide_on: [:index]
        field :created_at, as: :date_time, readonly: true, sortable: true, filterable: true
        field :updated_at, as: :date_time, readonly: true, sortable: true
      end
      # rubocop:enable Metrics/AbcSize

      def actions
        action Avo::Actions::SendInvoice
        action Avo::Actions::VoidInvoice
        action Avo::Actions::VoidInvoiceWithEmail
        action Avo::Actions::MarkPaid
        action Avo::Actions::ApplyDiscount
      end
    end
  end
end
