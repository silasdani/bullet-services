# frozen_string_literal: true

require 'googleauth'
require 'stringio'

module Fcm
  class CredentialsService
    FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'

    class << self
      def credentials
        @credentials ||= build_credentials
      end

      def project_id
        @project_id ||= extract_project_id
      end

      def reset!
        @credentials = nil
        @project_id = nil
        @service_account_json = nil
        @service_account_data = nil
      end

      private

      def build_credentials
        json_data = service_account_data
        return nil unless json_data

        Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: StringIO.new(json_data.to_json),
          scope: FCM_SCOPE
        )
      rescue StandardError => e
        Rails.logger.error("FCM credentials failed: #{e.message}")
        nil
      end

      def service_account_data
        return @service_account_data if defined?(@service_account_data) && @service_account_data

        json_string = service_account_json
        return nil unless json_string

        @service_account_data = JSON.parse(json_string)
      rescue JSON::ParserError => e
        Rails.logger.error("FCM JSON parse error: #{e.message}")
        nil
      end

      def service_account_json
        @service_account_json ||= fetch_service_account_json
      end

      def fetch_service_account_json
        ENV.fetch('FIREBASE_CREDENTIALS', nil) ||
          ENV.fetch('FCM_SERVICE_ACCOUNT_JSON', nil) ||
          read_from_file ||
          read_from_credentials
      end

      def read_from_file
        path = ENV.fetch('FCM_SERVICE_ACCOUNT_PATH', nil)
        return nil unless path&.present? && File.exist?(path)

        File.read(path)
      end

      def read_from_credentials
        json_data = Rails.application.credentials.dig(:fcm, :service_account_json)
        json_data.to_json if json_data.present?
      end

      def extract_project_id
        service_account_data&.dig('project_id')
      end
    end
  end
end
