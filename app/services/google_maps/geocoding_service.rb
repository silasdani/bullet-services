# frozen_string_literal: true

module GoogleMaps
  class GeocodingService < ApplicationService
    BASE_URL = 'https://maps.googleapis.com/maps/api/geocode/json'

    attribute :latitude
    attribute :longitude
    attribute :api_key

    attr_accessor :address

    def call
      return self if validate_coordinates.failure?
      return self if geocode.failure?

      self
    end

    private

    def validate_coordinates
      if latitude.blank? || longitude.blank?
        add_error('Latitude and longitude are required')
      elsif !valid_latitude?(latitude) || !valid_longitude?(longitude)
        add_error('Invalid latitude or longitude values')
      end
      self
    end

    def valid_latitude?(lat)
      lat.to_f.between?(-90, 90)
    end

    def valid_longitude?(lng)
      lng.to_f.between?(-180, 180)
    end

    def geocode
      response = make_request

      if response.success?
        parse_response(response)
      else
        handle_error(response)
      end

      self
    rescue StandardError => e
      log_error("Geocoding failed: #{e.message}")
      add_error("Geocoding service unavailable: #{e.message}")
      self
    end

    def make_request
      api_key_value = api_key || ENV.fetch('GOOGLE_MAPS_API_KEY', nil)

      unless api_key_value
        add_error('Google Maps API key not configured')
        return build_error_response
      end

      HTTParty.get(
        BASE_URL,
        query: {
          latlng: "#{latitude},#{longitude}",
          key: api_key_value
        },
        timeout: 5
      )
    end

    def parse_response(response)
      data = JSON.parse(response.body)

      case data['status']
      when 'OK'
        @address = extract_formatted_address(data)
        log_info("Geocoded address: #{@address}")
      when 'ZERO_RESULTS'
        log_warn('No address found for coordinates')
        @address = nil
      when 'OVER_QUERY_LIMIT'
        log_error('Google Maps API quota exceeded')
        add_error('Geocoding service temporarily unavailable')
      when 'REQUEST_DENIED'
        log_error("Geocoding request denied: #{data['error_message']}")
        add_error('Geocoding service configuration error')
      else
        log_warn("Geocoding status: #{data['status']}")
        @address = nil
      end
    end

    def extract_formatted_address(data)
      results = data['results']
      return nil if results.blank?

      results.first['formatted_address']
    end

    def handle_error(response)
      log_error("Geocoding HTTP error: #{response.code}")
      add_error('Geocoding service error')
    end

    def build_error_response
      ErrorResponse.new('{}')
    end

    # Simple response object to replace OpenStruct
    class ErrorResponse
      attr_reader :body

      def initialize(body)
        @body = body
      end

      def success?
        false
      end
    end
  end
end
