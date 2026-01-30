# frozen_string_literal: true

module Buildings
  class GeocodeJob < ApplicationJob
    queue_as :geocoding
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(building_id)
      building = Building.find(building_id)

      service = GeocodeService.new(building: building)
      service.call

      return if service.success?

      Rails.logger.error("Geocoding failed for building #{building_id}: #{service.errors.join(', ')}")
    end
  end
end
