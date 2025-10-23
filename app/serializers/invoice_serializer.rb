# frozen_string_literal: true

class InvoiceSerializer < ActiveModel::Serializer
  attributes :id, :name, :slug, :webflow_item_id, :is_archived, :is_draft,
             :webflow_created_on, :webflow_published_on, :freshbooks_client_id,
             :job, :wrs_link, :included_vat_amount, :excluded_vat_amount,
             :status_color, :status, :final_status, :invoice_pdf_link,
             :created_at, :updated_at

  attribute :total_amount
  attribute :archived?
  attribute :draft?
  attribute :published?
end
