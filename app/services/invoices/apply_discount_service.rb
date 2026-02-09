# frozen_string_literal: true

module Invoices
  class ApplyDiscountService < ApplicationService
    DISCOUNT_PERCENTAGE = 0.10
    VAT_RATE = 1.20

    def initialize(invoice:)
      super()
      @invoice = invoice
    end

    def call
      validate_invoice
      current_invoice = fetch_invoice
      invoice_lines = prepare_lines(current_invoice)
      lines = build_lines(invoice_lines, current_invoice)
      validate_total(lines)
      apply_discount(lines, current_invoice)
      sync_amounts
      @result = { message: '10% discount applied successfully' }
    rescue StandardError => e
      log_error(e.message)
      Rails.logger.error("Backtrace: #{e.backtrace.first(5).join('\n')}")
      add_error("Failed to apply discount: #{e.message}")
    end

    private

    attr_reader :invoice

    def validate_invoice
      raise StandardError, 'No FreshBooks invoice found' unless freshbooks_invoice
    end

    def freshbooks_invoice
      @freshbooks_invoice ||= invoice.freshbooks_invoices.first
    end

    def invoices_client
      @invoices_client ||= Freshbooks::Invoices.new
    end

    def fetch_invoice
      current_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)
      raise StandardError, 'Could not retrieve invoice from FreshBooks' unless current_invoice

      current_invoice
    end

    def prepare_lines(current_invoice)
      invoice_lines = filter_existing_discounts(current_invoice['lines'] || [])

      if invoice_lines.empty?
        invoice_lines = reconstruct_lines(current_invoice)
        raise StandardError, 'Invoice has no line items and amount is zero' unless invoice_lines
      end

      invoice_lines
    end

    def filter_existing_discounts(lines)
      lines.reject { |line| line['name']&.downcase&.include?('discount') }
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def reconstruct_lines(current_invoice)
      amount_data = current_invoice['amount'] || {}
      invoice_amount = extract_amount(amount_data)

      return nil if invoice_amount.zero?

      currency_code = extract_currency(amount_data, current_invoice)

      [{
        'name' => invoice.name || current_invoice['description'] || 'Invoice Item',
        'description' => invoice.job || invoice.wrs_link || current_invoice['notes'] || '',
        'qty' => 1,
        'unit_cost' => { 'amount' => invoice_amount.to_s, 'code' => currency_code },
        'type' => 0
      }]
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def extract_amount(amount_data)
      return 0.0 unless amount_data

      amount_data.is_a?(Hash) ? amount_data['amount'].to_f : amount_data.to_f
    end

    def extract_currency(amount_data, current_invoice)
      if amount_data.is_a?(Hash)
        amount_data['code'] || current_invoice['currency_code'] || 'USD'
      else
        current_invoice['currency_code'] || 'USD'
      end
    end

    def build_lines(invoice_lines, current_invoice)
      invoice_lines.map do |line|
        unit_cost = extract_unit_cost(line)
        quantity = (line['qty'] || line['quantity'] || 1).to_f
        build_line_item(line, unit_cost, quantity, current_invoice)
      end
    end

    def extract_unit_cost(line)
      unit_cost_data = line['unit_cost'] || {}
      cost_value = unit_cost_data.is_a?(Hash) ? unit_cost_data['amount'] : unit_cost_data
      cost_value.to_f
    end

    def build_line_item(line, unit_cost, quantity, current_invoice)
      currency = extract_currency_from_line(line, current_invoice)
      line_item = {
        name: line['name'],
        description: line['description'],
        quantity: quantity.to_i,
        cost: unit_cost,
        currency: currency,
        type: line['type'] || 0
      }

      add_tax_attributes(line_item, line, current_invoice)
      line_item
    end

    def extract_currency_from_line(line, current_invoice)
      unit_cost_data = line['unit_cost'] || {}
      currency = unit_cost_data.is_a?(Hash) ? unit_cost_data['code'] : nil
      currency || current_invoice['currency_code'] || 'USD'
    end

    def add_tax_attributes(line_item, line, current_invoice)
      line_item[:tax_amount1] = line['tax_amount1'] if line['tax_amount1'].present?
      line_item[:tax_amount2] = line['tax_amount2'] if line['tax_amount2'].present?

      tax_included = determine_tax_included(line, current_invoice)
      line_item[:tax_included] = tax_included if tax_included
    end

    def determine_tax_included(line, current_invoice)
      line['tax_included'].present? ? line['tax_included'] : current_invoice['tax_included'] == 'yes'
    end

    def validate_total(lines)
      total_amount = lines.sum { |line| line[:cost] * line[:quantity] }
      raise StandardError, 'Invoice total is zero. Cannot apply discount.' unless total_amount.positive?
    end

    def apply_discount(lines, current_invoice)
      total_amount = lines.sum { |line| line[:cost] * line[:quantity] }
      discount_line = build_discount_line(total_amount, current_invoice)
      lines << discount_line

      invoices_client.update(
        freshbooks_invoice.freshbooks_id,
        client_id: current_invoice['customerid'] || invoice.freshbooks_client_id,
        currency: current_invoice['currency_code'] || 'USD',
        lines: lines
      )
    end

    def build_discount_line(total_amount, current_invoice)
      discount_amount = total_amount * DISCOUNT_PERCENTAGE

      {
        name: '10% Discount',
        description: 'Applied 10% discount',
        quantity: 1,
        cost: -discount_amount.round(2),
        currency: current_invoice['currency_code'] || 'USD',
        type: 0,
        tax_included: current_invoice['tax_included'] == 'yes'
      }
    end

    # rubocop:disable Metrics/AbcSize
    def sync_amounts
      sleep(0.5)
      freshbooks_invoice.sync_from_freshbooks
      freshbooks_invoice.reload

      updated_invoice = invoices_client.get(freshbooks_invoice.freshbooks_id)
      amounts = calculate_amounts(updated_invoice)

      invoice.update_columns(
        excluded_vat_amount: amounts[:excluded].round(2),
        included_vat_amount: amounts[:included].round(2),
        updated_at: Time.current
      )
    end
    # rubocop:enable Metrics/AbcSize

    def calculate_amounts(updated_invoice)
      if updated_invoice
        amount_data = updated_invoice['amount'] || {}
        total_amount = extract_amount(amount_data)
        { included: total_amount, excluded: total_amount / VAT_RATE }
      else
        excluded = freshbooks_invoice.amount || 0
        { excluded: excluded, included: excluded * VAT_RATE }
      end
    end

    def log_error(message)
      Rails.logger.error("Failed to apply discount: #{message}")
    end
  end
end
