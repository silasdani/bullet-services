# frozen_string_literal: true

module Geocodable
  extend ActiveSupport::Concern

  included do
    # Callback to geocode on address changes
    after_save :geocode_if_address_changed, if: :should_geocode?
  end

  def geocode_if_address_changed
    return if latitude.present? && longitude.present? && !address_changed?

    # Use the appropriate job based on model name
    return unless instance_of?(::Building)

    Buildings::GeocodeJob.perform_later(id)
  end

  def should_geocode?
    respond_to?(:full_address) && full_address.present?
  end

  def address_changed?
    return false unless respond_to?(:saved_change_to_street?) || respond_to?(:saved_change_to_city?)

    saved_change_to_street? || saved_change_to_city? || saved_change_to_zipcode?
  end
end
