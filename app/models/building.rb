# frozen_string_literal: true

class Building < ApplicationRecord
  include SoftDeletable
  include Geocodable

  has_many :work_orders, dependent: :restrict_with_error
  has_many_attached :schedule_of_condition_images

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

  # Get address string: "{name}, {street}, {zipcode}"
  def address_string
    parts = [name, street, zipcode].compact.reject(&:blank?)
    parts.join(', ')
  end

  # Distance calculation method
  def distance_to(latitude, longitude)
    return nil unless self.latitude && self.longitude

    Location::DistanceCalculator.distance_in_meters(
      self.latitude,
      self.longitude,
      latitude,
      longitude
    )
  end

  def within_radius?(latitude, longitude, radius_meters = 15)
    return false unless self.latitude && self.longitude

    Location::DistanceCalculator.within_radius?(
      self.latitude,
      self.longitude,
      latitude,
      longitude,
      radius_meters
    )
  end

  # Ransack configuration for filtering
  def self.ransackable_attributes(_auth_object = nil)
    %w[name street city country zipcode created_at updated_at deleted_at latitude longitude]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end
