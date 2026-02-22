# frozen_string_literal: true

module Freshbooks
  class ConnectionCheckService
    def self.check
      new.check
    end

    def check
      token = FreshbooksToken.current
      access_token = token&.access_token || ENV['FRESHBOOKS_ACCESS_TOKEN'] || Rails.application.config.freshbooks[:access_token]

      return { ok: false, error: 'No token configured' } if access_token.blank?

      response = HTTParty.get(
        "#{Rails.application.config.freshbooks[:api_base_url]}/auth/api/v1/users/me",
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Api-Version' => 'alpha'
        }
      )

      if response.success?
        { ok: true }
      else
        { ok: false, error: error_message(response) }
      end
    rescue HTTParty::Error, StandardError => e
      { ok: false, error: e.message }
    end

    private

    def error_message(response)
      return "HTTP #{response.code}" unless response.body.present?

      parsed = JSON.parse(response.body)
      parsed['error_description'] || parsed['error'] || parsed['message'] || "HTTP #{response.code}"
    rescue JSON::ParserError
      "HTTP #{response.code}"
    end
  end
end
