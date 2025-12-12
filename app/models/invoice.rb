# frozen_string_literal: true

class Invoice < ApplicationRecord
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :webflow_item_id, uniqueness: true, allow_blank: true
  validates :freshbooks_client_id, presence: true
  validates :status, presence: true
  validates :final_status, presence: true

  validates :included_vat_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :excluded_vat_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(is_archived: [false, nil]) }
  scope :drafts, -> { where(is_draft: true) }
  scope :published, -> { where(is_draft: false) }

  def total_amount
    (included_vat_amount || 0) + (excluded_vat_amount || 0)
  end

  def archived?
    is_archived == true
  end

  def draft?
    is_draft == true
  end

  def published?
    !draft?
  end

  has_many :freshbooks_invoices, foreign_key: :invoice_id, dependent: :destroy

  has_one_attached :invoice_pdf

  # Create invoice in FreshBooks and optionally send email with payment link
  def create_in_freshbooks!(client_id:, lines: [], send_email: false, email_to: nil)
    service = Freshbooks::InvoiceCreationService.new(
      invoice: self,
      client_id: client_id,
      lines: lines,
      send_email: send_email,
      email_to: email_to
    )

    result = service.call
    raise StandardError, service.errors.join(', ') unless service.success?

    result
  end
end
