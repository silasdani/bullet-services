# frozen_string_literal: true

module RailsAdmin
  module InvoiceLifecycle
    # Defines which actions are allowed based on invoice status
    # Based on FreshBooks API invoice lifecycle documentation
    ACTION_RULES = {
      # Draft invoices can be sent, voided, edited, or have discounts applied
      'draft' => %w[send_invoice void_invoice void_invoice_with_email apply_discount mark_paid],

      # Sent invoices can be voided, marked as paid, or have discounts applied
      'sent' => %w[void_invoice void_invoice_with_email mark_paid apply_discount],

      # Viewed invoices can be voided, marked as paid, or have discounts applied
      'viewed' => %w[void_invoice void_invoice_with_email mark_paid apply_discount],

      # Paid invoices are final - no actions allowed except viewing
      'paid' => [],

      # Voided invoices are final - no actions allowed except viewing
      'void' => [],
      'voided' => [],

      # Disputed invoices can be resolved (handled separately) or voided
      'disputed' => %w[void_invoice void_invoice_with_email],

      # Partially paid invoices can be marked as fully paid or voided
      'partial' => %w[void_invoice void_invoice_with_email mark_paid apply_discount],

      # Overdue invoices can be voided, marked as paid, or have discounts applied
      'overdue' => %w[void_invoice void_invoice_with_email mark_paid apply_discount]
    }.freeze

    # Normalize status to handle variations
    def self.normalize_status(status)
      return nil if status.blank?

      normalized = status.to_s.downcase.strip

      # Handle variations
      case normalized
      when 'voided + email sent', 'voided+email sent'
        'voided'
      when 'sent - awaiting payment', 'sent-awaiting payment'
        'sent'
      else
        normalized
      end
    end

    # Check if an action is allowed for a given invoice status
    def self.action_allowed?(action_name, invoice)
      return false unless invoice.is_a?(Invoice)

      status = normalize_status(invoice.final_status || invoice.status || 'draft')
      allowed_actions = ACTION_RULES[status] || []

      # Convert action name to match our action names
      action_key = action_name.to_s

      allowed_actions.include?(action_key)
    end

    # Get all allowed actions for an invoice
    def self.allowed_actions(invoice)
      return [] unless invoice.is_a?(Invoice)

      status = normalize_status(invoice.final_status || invoice.status || 'draft')
      ACTION_RULES[status] || []
    end

    # Check if invoice can be voided
    def self.can_void?(invoice)
      return false unless invoice.is_a?(Invoice)

      status = normalize_status(invoice.final_status || invoice.status || 'draft')
      %w[draft sent viewed disputed partial overdue].include?(status)
    end

    # Check if invoice can be sent
    def self.can_send?(invoice)
      return false unless invoice.is_a?(Invoice)

      status = normalize_status(invoice.final_status || invoice.status || 'draft')
      status == 'draft'
    end

    # Check if invoice can be marked as paid
    def self.can_mark_paid?(invoice)
      return false unless invoice.is_a?(Invoice)

      status = normalize_status(invoice.final_status || invoice.status || 'draft')
      %w[draft sent viewed partial overdue].include?(status)
    end

    # Check if discount can be applied
    def self.can_apply_discount?(invoice)
      return false unless invoice.is_a?(Invoice)

      status = normalize_status(invoice.final_status || invoice.status || 'draft')
      %w[draft sent viewed partial overdue].include?(status)
    end

    # Check if invoice is in a final state (cannot be modified)
    def self.final_state?(invoice)
      return false unless invoice.is_a?(Invoice)

      status = normalize_status(invoice.final_status || invoice.status || 'draft')
      %w[paid void voided].include?(status)
    end
  end
end
