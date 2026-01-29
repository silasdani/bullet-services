# frozen_string_literal: true

module GoogleMaps
  class ForwardGeocodingService < ApplicationService
    BASE_URL = 'https://maps.googleapis.com/maps/api/geocode/json'

    attribute :address
    attribute :api_key

    attr_accessor :latitude, :longitude, :formatted_address

    def call
      return self if validate_address.failure?
      return self if geocode.failure?

      self
    end

    private

    def validate_address
      add_error('Address is required') if address.blank?
      self
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
          address: address,
          key: api_key_value
        },
        timeout: 5
      )
    end

    def parse_response(response)
      data = JSON.parse(response.body)
      case data['status']
      when 'OK' then parse_ok(data)
      when 'ZERO_RESULTS' then add_error('Address not found')
      when 'OVER_QUERY_LIMIT' then add_error('Geocoding service temporarily unavailable')
      else add_error("Geocoding failed: #{data['status']}")
      end
    end

    def parse_ok(data)
      result = data['results'].first
      location = result['geometry']['location']
      @latitude = location['lat'].to_f
      @longitude = location['lng'].to_f
      @formatted_address = result['formatted_address']
      log_info("Geocoded: #{address} -> #{@latitude}, #{@longitude}")
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

      def code
        500
      end
    end
  end
end
