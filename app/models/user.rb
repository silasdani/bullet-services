# frozen_string_literal: true

class User < ApplicationRecord
  extend Devise::Models
  include DeviseTokenAuth::Concerns::User
  has_one_attached :image

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  validates :role, presence: true

  enum :role, client: 0, employee: 1, admin: 2

  has_many :window_schedule_repairs, dependent: :destroy
  has_many :windows, through: :window_schedule_repairs

  after_initialize :set_default_role, if: :new_record?
  after_create :set_confirmed

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
end
