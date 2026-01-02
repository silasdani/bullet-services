# frozen_string_literal: true

class Invoice < ApplicationRecord
  include InvoiceStatus

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :webflow_item_id, uniqueness: true, allow_blank: true
  validates :freshbooks_client_id, presence: true, unless: -> { generated_by == 'wrs_form' }
  validates :status, presence: true
  validates :final_status, presence: true

  # Sync status from FreshbooksInvoice when invoice is updated and has FreshBooks invoices
  # Only sync if status wasn't just updated from FreshBooks (to avoid loops)
  after_update :sync_status_from_freshbooks_invoice, if: :should_sync_from_freshbooks?

  validates :included_vat_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :excluded_vat_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :not_archived, -> { where(is_archived: [false, nil]) }
  scope :drafts, -> { where(is_draft: true) }
  scope :published, -> { where(is_draft: false) }

  # Override active scope from InvoiceStatus to include is_archived check
  # Active invoices are not archived AND not voided
  def self.active
    where(is_archived: [false, nil]).where.not(status: %w[void voided])
  end

  def total_amount
    # Return only VAT-included amount (the actual chargeable amount)
    included_vat_amount || excluded_vat_amount || 0
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
  belongs_to :window_schedule_repair, optional: true

  has_one_attached :invoice_pdf

  # Ransack configuration for filtering
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      name slug status final_status status_color is_draft is_archived
      job flat_address generated_by freshbooks_client_id
      included_vat_amount excluded_vat_amount
      webflow_item_id webflow_collection_id
      webflow_created_on webflow_updated_on webflow_published_on
      wrs_link invoice_pdf_link
      created_at updated_at
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[freshbooks_invoices]
  end

  # Create invoice in FreshBooks and optionally send email with payment link
  def create_in_freshbooks!(client_id:, lines: [], send_email: false, email_to: nil)
    service = Freshbooks::InvoiceCreationService.new(
      invoice: self,
      client_id: client_id,
      lines: lines,
      send_email: send_email,
      email_to: email_to
    )

    service.call
    raise StandardError, service.errors.join(', ') unless service.success?

    service.result
  end

  # Get the primary FreshbooksInvoice (most recent or first)
  def primary_freshbooks_invoice
    freshbooks_invoices.order(created_at: :desc).first
  end

  # Sync status from FreshbooksInvoice if it exists
  def sync_status_from_freshbooks_invoice
    fb_invoice = primary_freshbooks_invoice
    return unless fb_invoice&.status.present?

    fb_status = fb_invoice.status
    invoice_status = map_freshbooks_status_to_invoice_status(fb_status)

    # Update if status differs
    return unless status != invoice_status || final_status != invoice_status

    update_columns(
      status: invoice_status,
      final_status: invoice_status,
      updated_at: Time.current
    )
  end

  private

  def should_sync_from_freshbooks?
    # Only sync if we have FreshBooks invoices
    return false unless freshbooks_invoices.any?

    # Don't sync if status was just updated (likely from FreshBooks callback)
    # This prevents infinite loops
    return false if saved_change_to_status? || saved_change_to_final_status?

    # Otherwise, check if we need to sync
    fb_invoice = primary_freshbooks_invoice
    return false unless fb_invoice&.status.present?

    # Sync if status differs
    fb_status = map_freshbooks_status_to_invoice_status(fb_invoice.status)
    status != fb_status || final_status != fb_status
  end
end
