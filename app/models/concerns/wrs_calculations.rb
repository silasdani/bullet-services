# frozen_string_literal: true

module WrsCalculations
  extend ActiveSupport::Concern

  included do
    before_save :calculate_totals
  end

  def subtotal
    calculate_subtotal
  end

  def vat_amount
    return 0 if total_vat_included_price.nil? || total_vat_excluded_price.nil?

    begin
      total_vat_included_price - total_vat_excluded_price
    rescue StandardError => e
      Rails.logger.error "Error calculating VAT amount: #{e.message}"
      0
    end
  end

  private

  def calculate_totals
    subtotal_amount = calculate_subtotal
    self.total_vat_excluded_price = subtotal_amount
    self.total_vat_included_price = (subtotal_amount * 1.2).round(2) # 20% VAT
    self.grand_total = total_vat_included_price
  rescue StandardError => e
    Rails.logger.error "Error calculating totals: #{e.message}"
    self.total_vat_excluded_price = 0
    self.total_vat_included_price = 0
    self.grand_total = 0
  end

  def calculate_subtotal
    subtotal = 0
    if windows.any?
      windows.each do |window|
        next unless window.tools.any?

        window.tools.each do |tool|
          subtotal += tool.price.to_f if tool.price
        end
      end
    end
    subtotal
  rescue StandardError => e
    Rails.logger.error "Error calculating subtotal: #{e.message}"
    0
  end
end
