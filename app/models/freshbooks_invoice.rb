# frozen_string_literal: true

class FreshbooksInvoice < ApplicationRecord
  include InvoiceStatus

  validates :freshbooks_id, presence: true, uniqueness: true
  validates :freshbooks_client_id, presence: true

  belongs_to :freshbooks_client, foreign_key: :freshbooks_client_id, primary_key: :freshbooks_id, optional: true
  belongs_to :invoice, optional: true
  has_many :freshbooks_payments, foreign_key: :freshbooks_invoice_id, primary_key: :freshbooks_id, dependent: :destroy

  scope :overdue, -> { where('due_date < ? AND status != ?', Date.current, 'paid') }

  # After status changes, propagate to Invoice model
  after_update :propagate_status_to_invoice, if: :saved_change_to_status?

  # After amount_outstanding changes, verify and reconcile if needed
  after_update :reconcile_if_needed, if: :saved_change_to_amount_outstanding?

  # Sync from FreshBooks when created
  after_create :sync_from_freshbooks_async, if: -> { freshbooks_id.present? }

  def sync_from_freshbooks
    Freshbooks::InvoiceLifecycleService.new(self).sync_from_freshbooks
  end

  def reconcile_payments
    Freshbooks::InvoiceLifecycleService.new(self).reconcile_payments
  end

  def verify_sync
    Freshbooks::InvoiceLifecycleService.new(self).verify_sync
  end

  private

  def propagate_status_to_invoice
    return unless invoice

    invoice_status = map_freshbooks_status_to_invoice_status(status)
    return if invoice.status == invoice_status && invoice.final_status == invoice_status

    invoice.update_columns(
      status: invoice_status,
      final_status: invoice_status,
      updated_at: Time.current
    )
  end

  def reconcile_if_needed
    # If outstanding amount is 0 or negative but status isn't paid, reconcile
    return unless amount_outstanding.to_f <= 0 && status != 'paid' && status != 'void' && status != 'voided'

    reconcile_payments
  end

  def sync_from_freshbooks_async
    Freshbooks::SyncInvoicesJob.perform_later(freshbooks_id)
  end
end
