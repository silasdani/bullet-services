# frozen_string_literal: true

module WorkOrderCalculations
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

  def vat_rate
    VAT_RATE
  end

  def total
    total_vat_included_price || 0
  end

  # Snapshot current prices for historical record
  def snapshot_prices!
    return unless persisted?

    price_snapshots.create!(
      subtotal: total_vat_excluded_price || 0,
      vat_rate: VAT_RATE,
      vat_amount: vat_amount,
      total: total_vat_included_price || 0,
      snapshot_at: Time.current,
      line_items: build_line_items_snapshot
    )
  rescue StandardError => e
    Rails.logger.error "Error creating price snapshot: #{e.message}"
    raise
  end

  private

  def calculate_totals
    subtotal_amount = calculate_subtotal
    self.total_vat_excluded_price = subtotal_amount
    self.total_vat_included_price = (subtotal_amount * (1 + VAT_RATE)).round(2)
  rescue StandardError => e
    Rails.logger.error "Error calculating totals: #{e.message}"
    self.total_vat_excluded_price = 0
    self.total_vat_included_price = 0
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

  def build_line_items_snapshot
    {
      windows: windows.map do |window|
        {
          window_id: window.id,
          location: window.location,
          tools: window.tools.map do |tool|
            {
              tool_id: tool.id,
              name: tool.name,
              price: tool.price.to_f
            }
          end
        }
      end
    }
  end
end
