# frozen_string_literal: true

class PriceSnapshot < ApplicationRecord
  include SoftDeletable

  belongs_to :priceable, polymorphic: true

  validates :snapshot_at, presence: true
  validates :subtotal, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :vat_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :vat_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :total, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :recent, -> { order(snapshot_at: :desc) }
  scope :for_priceable, ->(priceable) { where(priceable: priceable) }

  def vat_percentage
    return 0 if vat_rate.nil?

    (vat_rate * 100).round(2)
  end
end
