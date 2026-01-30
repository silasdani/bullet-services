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

      response = HTTParty.post(
        url,
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json'
        },
        body: { message: build_payload }.to_json,
        timeout: 10
      )

      handle_response(response)
    end

    def build_payload
      {
        token: user.fcm_token,
        notification: { title: title, body: body },
        data: data.transform_keys(&:to_s),
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
        add_error('Invalid FCM request')
      when 401, 403
        add_error('FCM authentication failed')
      when 404
        handle_invalid_token(response)
      else
        log_error("FCM error #{response.code}")
        add_error('FCM service error')
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
