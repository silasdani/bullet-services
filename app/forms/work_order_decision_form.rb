# frozen_string_literal: true

class WorkOrderDecisionForm
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
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: 'is invalid' }
end
