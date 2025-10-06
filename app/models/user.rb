# frozen_string_literal: true

class User < ApplicationRecord
  extend Devise::Models
  include DeviseTokenAuth::Concerns::User
  has_one_attached :image

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable #, :confirmable

  validates :role, presence: true

  enum :role, client: 0, employee: 1, admin: 2, super_admin: 3

  has_many :window_schedule_repairs, dependent: :restrict_with_error
  has_many :windows, through: :window_schedule_repairs

  # Soft delete functionality
  default_scope { where(deleted_at: nil) }
  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
  scope :with_deleted, -> { unscoped }

  after_initialize :set_default_role, if: :new_record?
  after_create :set_confirmed


  # Role helper methods
  def is_admin?
    role == 'admin' || role == 2 || role == 'super_admin' || role == 3
  end

  def is_employee?
    role == 'employee' || role == 1
  end

  def is_super_admin?
    role == 'super_admin' || role == 3
  end

  def token_validation_response
    UserSerializer.new(self).as_json
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  def active?
    deleted_at.nil?
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
end
