# frozen_string_literal: true

module Buildings
  class GeocodeService < ApplicationService
    attribute :building

    def call
      return self if building.nil?
      return self if building.latitude.present? && building.longitude.present?

      geocode_address
      self
    end

    private

    def geocode_address
      service = GoogleMaps::ForwardGeocodingService.new(address: building.full_address)
      service.call
      service.success? ? apply_geocode_result(service) : log_geocode_failure(service)
    end

    def apply_geocode_result(service)
      building.update!(latitude: service.latitude, longitude: service.longitude)
      log_info("Geocoded building #{building.id}")
    end

    def log_geocode_failure(service)
      log_warn("Failed to geocode building #{building.id}: #{service.errors.join(', ')}")
      add_errors(service.errors)
    end
  end
end
