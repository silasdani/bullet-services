# frozen_string_literal: true

module Fcm
  class SendNotificationService < ApplicationService
    attribute :user
    attribute :title
    attribute :body
    attribute :data, default: -> { {} }

    def call
      return self unless user&.fcm_token.present?
      return self unless credentials_available?

      send_notification
      self
    end

    private

    def credentials_available?
      return true if CredentialsService.credentials && CredentialsService.project_id

      log_warn('FCM not configured')
      false
    end

    def send_notification
      access_token = fetch_access_token
      return self unless access_token

      send_fcm_request(access_token)
      self
    rescue StandardError => e
      log_error("FCM send failed: #{e.message}")
      add_error('Failed to send push notification')
      self
    end

    def fetch_access_token
      CredentialsService.credentials.fetch_access_token!['access_token']
    rescue Google::Auth::AuthorizationError => e
      log_error("FCM auth error: #{e.message}")
      add_error('FCM authentication failed')
      nil
    rescue StandardError => e
      log_error("FCM token error: #{e.message}")
      add_error('FCM authentication failed')
      nil
    end

    def send_fcm_request(access_token)
      url = "https://fcm.googleapis.com/v1/projects/#{CredentialsService.project_id}/messages:send"
      payload = build_payload
      request_body = { message: payload }

      log_debug("Sending FCM request to user #{user.id} (#{user.email}): #{request_body.to_json}")

      response = HTTParty.post(
        url,
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json'
        },
        body: request_body.to_json,
        timeout: 10
      )

      handle_response(response)
    end

    def build_payload
      # Ensure all data values are strings (FCM requirement)
      transformed_data = data.transform_keys(&:to_s).transform_values(&:to_s)
      
      {
        token: user.fcm_token,
        notification: { title: title, body: body },
        data: transformed_data,
        android: { priority: 'high' },
        apns: {
          headers: { 'apns-priority' => '10' },
          payload: { aps: { 'content-available' => 1 } }
        }
      }
    end

    def handle_response(response)
      return log_info("FCM sent to user #{user.id}") if response.success?

      case response.code
      when 400
        error_details = parse_error_response(response)
        log_error("FCM 400 error for user #{user.id}: #{error_details}")
        add_error('Invalid FCM request')
      when 401, 403
        error_details = parse_error_response(response)
        log_error("FCM auth error #{response.code} for user #{user.id}: #{error_details}")
        add_error('FCM authentication failed')
      when 404
        handle_invalid_token(response)
      else
        error_details = parse_error_response(response)
        log_error("FCM error #{response.code} for user #{user.id}: #{error_details}")
        add_error('FCM service error')
      end
    end

    def parse_error_response(response)
      begin
        parsed = response.parsed_response
        error_message = parsed.dig('error', 'message')
        error_code = parsed.dig('error', 'details', 0, 'errorCode')
        "Message: #{error_message}, Code: #{error_code}, Full response: #{parsed.inspect}"
      rescue StandardError => e
        "Could not parse error response: #{e.message}, Raw body: #{response.body}"
      end
    end

    def handle_invalid_token(response)
      error_code = begin
        response.parsed_response.dig('error', 'details', 0, 'errorCode')
      rescue StandardError
        nil
      end
      if %w[UNREGISTERED INVALID_ARGUMENT].include?(error_code)
        log_warn("FCM token invalid for user #{user.id}")
        user.update(fcm_token: nil)
        add_error('FCM token invalid - removed')
      else
        add_error('FCM service error')
      end
    end
  end
end
