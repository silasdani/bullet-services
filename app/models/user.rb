# frozen_string_literal: true

class User < ApplicationRecord
  extend Devise::Models
  include DeviseTokenAuth::Concerns::User
  include SoftDeletable

  has_one_attached :image

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :role, presence: true

  enum :role, client: 0, contractor: 1, admin: 2, surveyor: 3

  has_many :building_assignments, dependent: :destroy
  has_many :assigned_buildings, through: :building_assignments, source: :building
  has_many :window_schedule_repairs, dependent: :restrict_with_error
  has_many :windows, through: :window_schedule_repairs
  has_many :check_ins, dependent: :destroy
  has_many :ongoing_works, dependent: :destroy
  has_many :notifications, dependent: :destroy

  before_validation :set_default_role, on: :create
  after_create :set_confirmed
  before_save :sync_uid_with_email

  # Role helper methods - optimized to use enum values directly
  def admin?
    role.in?(%w[admin])
  end

  def contractor?
    role == 'contractor'
  end

  def surveyor?
    role == 'surveyor'
  end

  def webflow_access?
    admin?
  end

  # Deprecated: Use admin? instead
  # rubocop:disable Naming/PredicatePrefix
  def is_admin?
    admin?
  end

  # Deprecated: Use contractor? instead
  def is_employee?
    contractor?
  end

  # rubocop:enable Naming/PredicatePrefix

  def token_validation_response
    UserSerializer.new(self).as_json
  end

  def set_confirmed
    self.confirmed_at = Time.current
    save(validate: false)
  end

  def blocked?
    blocked == true
  end

  def block!
    update!(blocked: true)
  end

  def unblock!
    update!(blocked: false)
  end

  # Users soft-deleted at least this long ago are eligible for permanent deletion
  PERMANENT_DELETION_GRACE_DAYS = 30

  scope :pending_permanent_deletion, lambda {
    deleted.where('deleted_at < ?', PERMANENT_DELETION_GRACE_DAYS.days.ago)
  }

  def self.ransackable_attributes(_auth_object = nil)
    %w[name email role blocked created_at updated_at deleted_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def set_default_role
    self.role = :contractor if role.nil? || role == 'client' || role.zero?
  end

  def sync_uid_with_email
    return unless email.present? && (uid.blank? || uid != email)

    self.uid = email
  end
end
