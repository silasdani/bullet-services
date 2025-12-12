# frozen_string_literal: true

class FreshbooksPayment < ApplicationRecord
  validates :freshbooks_id, presence: true, uniqueness: true
  validates :freshbooks_invoice_id, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :date, presence: true

  belongs_to :freshbooks_invoice, foreign_key: :freshbooks_invoice_id, primary_key: :freshbooks_id, optional: true
end
