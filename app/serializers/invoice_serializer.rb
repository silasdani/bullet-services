# frozen_string_literal: true

class InvoiceSerializer < ActiveModel::Serializer
  attributes :id, :name, :slug, :is_archived, :is_draft,
             :freshbooks_client_id, :job, :wrs_link,
             :included_vat_amount, :excluded_vat_amount,
             :status_color, :status, :final_status, :invoice_pdf_link,
             :work_order_id, :created_at, :updated_at

  attribute :total_amount
  attribute :archived?
  attribute :draft?
  attribute :published?
end
