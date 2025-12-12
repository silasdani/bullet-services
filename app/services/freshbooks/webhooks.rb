# frozen_string_literal: true

module Freshbooks
  class Webhooks < BaseClient
    def list
      # FreshBooks webhook API: GET /events/account/<account_id>/events/callbacks
      access_token = access_token_value
      business_id = business_id_value

      response = HTTParty.get(
        "https://api.freshbooks.com/events/account/#{business_id}/events/callbacks",
        headers: webhook_headers(access_token)
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

    def create(event:, callback_url:)
      # FreshBooks webhook API: POST /events/account/<account_id>/events/callbacks
      # Based on: https://www.freshbooks.com/api/webhooks
      payload = build_callback_payload(event: event, uri: callback_url)
      response = make_webhook_request(:post, 'events/callbacks', payload)

      handle_webhook_response(response, 'register')
    end

    def delete(callback_id)
      # FreshBooks webhook API: DELETE /events/account/<account_id>/events/callbacks/<callback_id>
      access_token = access_token_value
      business_id = business_id_value

      response = HTTParty.delete(
        "https://api.freshbooks.com/events/account/#{business_id}/events/callbacks/#{callback_id}",
        headers: webhook_headers(access_token)
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
      payload = build_callback_payload(verifier: verification_code)
      response = make_webhook_request(:put, "events/callbacks/#{callback_id}", payload)

      handle_webhook_response(response, 'verify')
    end

    def resend_verification(callback_id)
      # Resend verification code
      payload = build_callback_payload(resend: true)
      response = make_webhook_request(:put, "events/callbacks/#{callback_id}", payload)

      handle_webhook_response(response, 'resend verification')
    end

    private

    def build_callback_payload(**options)
      { callback: options }
    end

    def make_webhook_request(method, endpoint, payload)
      access_token = access_token_value
      business_id = business_id_value
      url = "https://api.freshbooks.com/events/account/#{business_id}/#{endpoint}"

      HTTParty.public_send(
        method,
        url,
        body: payload.to_json,
        headers: webhook_headers(access_token)
      )
    end

    def webhook_headers(access_token)
      {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json',
        'Api-Version' => 'alpha'
      }
    end

    def handle_webhook_response(response, action)
      if response.success?
        response.parsed_response.dig('response', 'result', 'callback')
      else
        error_body = response.body || '(empty response)'
        raise FreshbooksError.new(
          "Failed to #{action} webhook: #{error_body}",
          response.code,
          error_body
        )
      end
    end

    def access_token_value
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

    def business_id_value
      return @business_id if @business_id.present?

      token = FreshbooksToken.current
      return token.business_id if token&.business_id.present?

      business_id = ENV['FRESHBOOKS_BUSINESS_ID'] || Rails.application.config.freshbooks[:business_id]
      raise FreshbooksError, 'FreshBooks business ID not configured' if business_id.blank?

      business_id
    end
  end
end
