# frozen_string_literal: true

namespace :buildings do
  desc 'Geocode all buildings that are missing latitude/longitude'
  task geocode: :environment do
    puts 'Starting geocoding process...'

    # Find buildings without geocoding data
    buildings_to_geocode = Building.where(latitude: nil).or(Building.where(longitude: nil))
                                   .where(deleted_at: nil)

    total = buildings_to_geocode.count
    puts "Found #{total} buildings to geocode"

    if total.zero?
      puts 'No buildings need geocoding.'
      next
    end

    success_count = 0
    error_count = 0

    buildings_to_geocode.find_each.with_index do |building, index|
      print "Geocoding building #{index + 1}/#{total}: #{building.name} (#{building.full_address})... "

      service = Buildings::GeocodeService.new(building: building)
      service.call

      if service.success?
        puts '✓ Success'
        success_count += 1
      else
        puts "✗ Failed: #{service.errors.join(', ')}"
        error_count += 1
      end

      # Small delay to avoid rate limiting
      sleep(0.1) if index < total - 1
    end

    puts "\nGeocoding complete!"
    puts "Successfully geocoded: #{success_count}"
    puts "Failed: #{error_count}"
  end
end
