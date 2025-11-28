# frozen_string_literal: true

module Freshbooks
  class Webhooks < BaseClient
    def list
      # FreshBooks webhook API: GET /events/account/<account_id>/events/callbacks
      access_token = get_access_token
      business_id = get_business_id

      response = HTTParty.get(
        "https://api.freshbooks.com/events/account/#{business_id}/events/callbacks",
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json',
          'Api-Version' => 'alpha'
        }
      )

      if response.success?
        response.parsed_response.dig('response', 'result', 'callbacks') || []
      else
        raise FreshbooksError.new(
          "Failed to list webhooks: #{response.body}",
          response.code,
          response.body
        )
      end
    end

    def create(event:, callback_url:, verifier: nil)
      # FreshBooks webhook API: POST /events/account/<account_id>/events/callbacks
      # Based on: https://www.freshbooks.com/api/webhooks
      access_token = get_access_token
      business_id = get_business_id

      payload = {
        callback: {
          event: event,
          uri: callback_url
        }
      }

      response = HTTParty.post(
        "https://api.freshbooks.com/events/account/#{business_id}/events/callbacks",
        body: payload.to_json,
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json',
          'Api-Version' => 'alpha'
        }
      )

      if response.success?
        response.parsed_response.dig('response', 'result', 'callback')

      else
        error_body = response.body || '(empty response)'
        raise FreshbooksError.new(
          "Failed to register webhook: #{error_body}",
          response.code,
          error_body
        )
      end
    end

    def delete(callback_id)
      # FreshBooks webhook API: DELETE /events/account/<account_id>/events/callbacks/<callback_id>
      access_token = get_access_token
      business_id = get_business_id

      response = HTTParty.delete(
        "https://api.freshbooks.com/events/account/#{business_id}/events/callbacks/#{callback_id}",
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json',
          'Api-Version' => 'alpha'
        }
      )

      response.success? || raise(FreshbooksError.new(
                                   "Failed to delete webhook: #{response.body}",
                                   response.code,
                                   response.body
                                 ))
    end

    def verify(callback_id, verification_code)
      # FreshBooks webhook API: PUT /events/account/<account_id>/events/callbacks/<callback_id>
      # The verifier is sent during verification, not registration
      access_token = get_access_token
      business_id = get_business_id

      payload = {
        callback: {
          verifier: verification_code
        }
      }

      response = HTTParty.put(
        "https://api.freshbooks.com/events/account/#{business_id}/events/callbacks/#{callback_id}",
        body: payload.to_json,
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json',
          'Api-Version' => 'alpha'
        }
      )

      if response.success?
        response.parsed_response.dig('response', 'result', 'callback')
      else
        raise FreshbooksError.new(
          "Failed to verify webhook: #{response.body}",
          response.code,
          response.body
        )
      end
    end

    def resend_verification(callback_id)
      # Resend verification code
      access_token = get_access_token
      business_id = get_business_id

      payload = {
        callback: {
          resend: true
        }
      }

      response = HTTParty.put(
        "https://api.freshbooks.com/events/account/#{business_id}/events/callbacks/#{callback_id}",
        body: payload.to_json,
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json',
          'Api-Version' => 'alpha'
        }
      )

      if response.success?
        response.parsed_response.dig('response', 'result', 'callback')
      else
        raise FreshbooksError.new(
          "Failed to resend verification: #{response.body}",
          response.code,
          response.body
        )
      end
    end

    private

    def get_access_token
      # Try instance variable first
      return @access_token if @access_token.present?

      # Then try database
      token = FreshbooksToken.current
      return token.access_token if token&.access_token.present?

      # Finally try environment
      token = ENV['FRESHBOOKS_ACCESS_TOKEN'] || Rails.application.config.freshbooks[:access_token]
      raise FreshbooksError, 'FreshBooks access token not configured' if token.blank?

      token
    end

    def get_business_id
      return @business_id if @business_id.present?

      token = FreshbooksToken.current
      return token.business_id if token&.business_id.present?

      business_id = ENV['FRESHBOOKS_BUSINESS_ID'] || Rails.application.config.freshbooks[:business_id]
      raise FreshbooksError, 'FreshBooks business ID not configured' if business_id.blank?

      business_id
    end
  end
end
