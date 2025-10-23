# frozen_string_literal: true

class Invoice < ApplicationRecord
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :webflow_item_id, uniqueness: true, allow_blank: true
  validates :freshbooks_client_id, presence: true
  validates :status, presence: true
  validates :final_status, presence: true

  validates :included_vat_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :excluded_vat_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(is_archived: [false, nil]) }
  scope :drafts, -> { where(is_draft: true) }
  scope :published, -> { where(is_draft: false) }

  def total_amount
    (included_vat_amount || 0) + (excluded_vat_amount || 0)
  end

  def archived?
    is_archived == true
  end

  def draft?
    is_draft == true
  end

  def published?
    !draft?
  end
end
