# frozen_string_literal: true

class FreshbooksClient < ApplicationRecord
  validates :freshbooks_id, presence: true, uniqueness: true

  has_many :freshbooks_invoices, foreign_key: :freshbooks_client_id, primary_key: :freshbooks_id, dependent: :destroy

  def full_name
    [first_name, last_name].compact.join(' ').presence || organization
  end
end
