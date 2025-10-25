# frozen_string_literal: true

module Webflow
  class BaseService
    include HTTParty

    base_uri 'https://api.webflow.com/v2'

    def initialize
      @api_key = Rails.application.credentials.webflow&.dig(:api_key) || ENV.fetch('WEBFLOW_TOKEN', nil)
      @site_id = Rails.application.credentials.webflow&.dig(:site_id) || ENV.fetch('WEBFLOW_SITE_ID', nil)

      raise 'Webflow API key not configured' if @api_key.blank?
      raise 'Webflow site ID not configured' if @site_id.blank?
    end

    private

    def headers
      {
        'Authorization' => "Bearer #{@api_key}",
        'accept-version' => '2.0.0',
        'Content-Type' => 'application/json'
      }
    end

    def make_request(method, path, options = {})
      options[:headers] = headers.merge(options[:headers] || {})

      response = self.class.send(method, path, options)

      case response.code
      when 200..299
        response.parsed_response
      when 429
        handle_rate_limit(response)
      else
        raise WebflowApiError.new(
          "Webflow API error: #{response.code}",
          response.code,
          response.body
        )
      end
    rescue HTTParty::Error => e
      raise WebflowApiError, "Network error: #{e.message}"
    end

    def handle_rate_limit(response)
      retry_after = response.headers['Retry-After']&.to_i || 60
      sleep(retry_after)
      raise WebflowApiError, "Rate limited, retry after #{retry_after} seconds"
    end
  end
end
