# frozen_string_literal: true

module Location
  class DistanceCalculator
    EARTH_RADIUS_KM = 6371.0
    EARTH_RADIUS_M = 6_371_000.0

    def self.distance_in_meters(lat1, lon1, lat2, lon2)
      return nil if [lat1, lon1, lat2, lon2].any?(&:nil?)

      (EARTH_RADIUS_M * haversine_c(lat1, lon1, lat2, lon2)).round(2)
    end

    def self.haversine_c(lat1, lon1, lat2, lon2)
      dlat = to_radians(lat2 - lat1)
      dlon = to_radians(lon2 - lon1)
      a = haversine_a(dlat, dlon, lat1, lat2)
      2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    end

    def self.haversine_a(dlat, dlon, lat1, lat2)
      (Math.sin(dlat / 2)**2) +
        (Math.cos(to_radians(lat1)) * Math.cos(to_radians(lat2)) * (Math.sin(dlon / 2)**2))
    end

    def self.within_radius?(lat1, lon1, lat2, lon2, radius_meters)
      distance = distance_in_meters(lat1, lon1, lat2, lon2)
      return false unless distance

      distance <= radius_meters
    end

    def self.to_radians(degrees)
      degrees * Math::PI / 180.0
    end
  end
end
