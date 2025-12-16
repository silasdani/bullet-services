# frozen_string_literal: true

class WrsDecisionForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :first_name, :string
  attribute :last_name, :string
  attribute :email, :string
  attribute :decision, :string
  attribute :accept_terms, :boolean

  validates :first_name, :last_name, :email, presence: true
  validates :decision, presence: true, inclusion: { in: %w[accept decline] }
  validates :accept_terms, acceptance: { accept: true }
  validate :email_format

  def email_format
    return if email.blank?

    regex = /\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i
    errors.add(:email, 'is invalid') unless email.match?(regex)
  end
end

