# frozen_string_literal: true

module CheckIns
  module AddressResolver
    def resolve_address
      return address if address.present?
      return nil unless coordinates_present?

      geocoding_service = call_geocoding_service

      extract_address_or_fallback(geocoding_service)
    end

    private

    def coordinates_present?
      latitude.present? && longitude.present?
    end

    def call_geocoding_service
      service = GoogleMaps::GeocodingService.new(
        latitude: latitude,
        longitude: longitude
      )
      service.call
      service
    end

    def extract_address_or_fallback(geocoding_service)
      if geocoding_service.success? && geocoding_service.address.present?
        geocoding_service.address
      else
        log_warn("Geocoding failed: #{geocoding_service.errors.join(', ')}")
        "#{latitude}, #{longitude}"
      end
    end
  end
end
