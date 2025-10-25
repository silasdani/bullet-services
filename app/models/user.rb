# frozen_string_literal: true

class User < ApplicationRecord
  extend Devise::Models
  include DeviseTokenAuth::Concerns::User
  include SoftDeletable

  has_one_attached :image

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :role, presence: true

  enum :role, client: 0, employee: 1, admin: 2, super_admin: 3

  has_many :window_schedule_repairs, dependent: :restrict_with_error
  has_many :windows, through: :window_schedule_repairs

  after_initialize :set_default_role, if: :new_record?
  after_create :set_confirmed
  before_save :sync_uid_with_email

  # Role helper methods
  def is_admin?
    ['admin', 2, 'super_admin', 3].include?(role)
  end

  def is_employee?
    ['employee', 1].include?(role)
  end

  def is_super_admin?
    ['super_admin', 3].include?(role)
  end

  def webflow_access
    is_admin? || is_employee?
  end

  def token_validation_response
    UserSerializer.new(self).as_json
  end

  def set_confirmed
    self.confirmed_at = Time.current
    save(validate: false)
  rescue StandardError => e
    Rails.logger.error("Failed to set confirmed_at for user #{id}: #{e.message}")
  end

  private

  def set_default_role
    self.role ||= :client
  end

  def sync_uid_with_email
    # For email-based authentication, UID should match the email
    return unless email.present? && (uid.blank? || uid != email)

    self.uid = email
  end
end
