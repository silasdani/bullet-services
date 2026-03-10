# frozen_string_literal: true

class Assignment < ApplicationRecord
  belongs_to :user
  belongs_to :building
  belongs_to :assigned_by_user, class_name: 'User', optional: true

  # Reuses User role integers, excluding :admin (2) and :client (0).
  enum :role, { contractor: 1, surveyor: 3, general_contractor: 4, supervisor: 5, contract_manager: 6 }

  FORBIDDEN_PROJECT_ROLES = %w[admin client].freeze

  validates :user_id, presence: true
  validates :building_id, presence: true
  validates :building_id, uniqueness: { scope: :user_id }
  validates :role, presence: true
  validate :role_not_forbidden

  before_validation :set_default_role, on: :create

  def display_title
    "#{user&.name || user&.email} → #{building&.name} (#{role&.humanize})"
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[role user_id building_id assigned_by_user_id created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[user building assigned_by_user]
  end

  private

  def set_default_role
    return if role.present?

    self.role = if user&.role == 'admin'
                  :contract_manager
                else
                  user&.role&.to_sym || :contractor
                end
  end

  def role_not_forbidden
    return unless role.present?

    errors.add(:role, 'cannot be admin or client on a project') if FORBIDDEN_PROJECT_ROLES.include?(role.to_s)
  end
end
