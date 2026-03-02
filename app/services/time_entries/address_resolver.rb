# frozen_string_literal: true

module TimeEntries
  module AddressResolver
    def resolve_address
      return nil unless latitude.present? && longitude.present?

      service = GoogleMaps::GeocodingService.new(latitude: latitude, longitude: longitude)
      service.call
      if service.success? && service.address.present?
        service.address
      else
        log_warn("Geocoding failed: #{service.errors.join(', ')}") if service.errors.any?
        "#{latitude}, #{longitude}"
      end
    end
  end
end
