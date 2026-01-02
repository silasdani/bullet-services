# frozen_string_literal: true

# Shared concern for invoice status management
# Ensures consistent status values across Invoice and FreshbooksInvoice models
module InvoiceStatus
  extend ActiveSupport::Concern

  # Valid invoice statuses (matching FreshBooks API)
  VALID_STATUSES = %w[draft sent viewed paid void voided].freeze

  # Status transitions that are allowed
  STATUS_TRANSITIONS = {
    'draft' => %w[sent void voided],
    'sent' => %w[viewed paid void voided],
    'viewed' => %w[paid void voided],
    'paid' => [], # Paid is final
    'void' => [], # Void is final
    'voided' => [] # Voided is final
  }.freeze

  included do
    # Validate status is one of the valid values
    validates :status, inclusion: { in: VALID_STATUSES, message: 'is not a valid invoice status' }, allow_nil: true

    # Normalize status on assignment
    before_validation :normalize_status_value
  end

  class_methods do
    # Scope for each status
    VALID_STATUSES.each do |status_value|
      define_method(status_value) do
        where(status: status_value)
      end
    end

    # Scope for unpaid invoices (not paid, void, or voided)
    def unpaid
      where.not(status: %w[paid void voided])
    end

    # Scope for paid invoices
    def paid
      where(status: 'paid')
    end

    # Scope for voided invoices (void or voided)
    def voided
      where(status: %w[void voided])
    end

    # Scope for active invoices (not voided)
    def active
      where.not(status: %w[void voided])
    end
  end

  # Instance methods
  def draft?
    status == 'draft'
  end

  def sent?
    status == 'sent'
  end

  def viewed?
    status == 'viewed'
  end

  def paid?
    status == 'paid'
  end

  def void?
    status == 'void' || status == 'voided'
  end

  def voided?
    status == 'void' || status == 'voided'
  end

  def unpaid?
    !paid? && !void?
  end

  def active?
    !void?
  end

  # Normalize status value to handle variations
  def normalize_status_value
    return if status.blank?

    normalized = status.to_s.downcase.strip

    # Handle variations
    case normalized
    when 'voided + email sent', 'voided+email sent', 'voided'
      self.status = 'voided'
    when 'sent - awaiting payment', 'sent-awaiting payment'
      self.status = 'sent'
    when 'void'
      self.status = 'voided' # Standardize to 'voided'
    else
      self.status = normalized if VALID_STATUSES.include?(normalized)
    end
  end

  # Check if a status transition is valid
  def can_transition_to?(new_status)
    return false if new_status.blank?
    return true if status.blank? # Can set initial status

    normalized_new = new_status.to_s.downcase.strip
    normalized_new = 'voided' if normalized_new == 'void'

    STATUS_TRANSITIONS[status]&.include?(normalized_new) || false
  end

  # Get the canonical status (normalized)
  def canonical_status
    normalize_status_value
    status
  end
end
