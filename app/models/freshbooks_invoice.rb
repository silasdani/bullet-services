# frozen_string_literal: true

class FreshbooksInvoice < ApplicationRecord
  validates :freshbooks_id, presence: true, uniqueness: true
  validates :freshbooks_client_id, presence: true

  belongs_to :freshbooks_client, foreign_key: :freshbooks_client_id, primary_key: :freshbooks_id, optional: true
  belongs_to :invoice, optional: true

  scope :paid, -> { where(status: 'paid') }
  scope :unpaid, -> { where.not(status: 'paid') }
  scope :overdue, -> { where('due_date < ? AND status != ?', Date.current, 'paid') }
end
