# frozen_string_literal: true

class Building < ApplicationRecord
  include SoftDeletable

  has_many :window_schedule_repairs, dependent: :restrict_with_error

  validates :name, presence: true
  validates :street, presence: true
  validates :city, presence: true
  validates :country, presence: true

  # Ensure only one building per unique address (case-insensitive, ignoring deleted)
  validates :street, uniqueness: {
    scope: %i[city zipcode],
    case_sensitive: false,
    conditions: -> { where(deleted_at: nil) },
    message: 'A building with this address already exists'
  }

  # Full address string representation
  def full_address
    parts = [street]
    parts << city if city.present?
    parts << zipcode if zipcode.present?
    parts << country if country.present?
    parts.join(', ')
  end

  # Display name combining building name and address
  def display_name
    "#{name} - #{full_address}"
  end

  # Get address string in Webflow format: "{name}, {street}, {zipcode}"
  def address_string
    parts = [name, street, zipcode].compact.reject(&:blank?)
    parts.join(', ')
  end

  # Ransack configuration for filtering
  def self.ransackable_attributes(_auth_object = nil)
    %w[name street city country zipcode created_at updated_at deleted_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
