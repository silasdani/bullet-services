# frozen_string_literal: true

module Freshbooks
  class BaseClient
    include HTTParty
    include TokenRefresh

    base_uri Rails.application.config.freshbooks[:api_base_url]

    def initialize(access_token: nil, refresh_token: nil, business_id: nil)
      @access_token = access_token || access_token_from_config
      @refresh_token = refresh_token || refresh_token_from_config
      @business_id = business_id || business_id_from_config

      raise FreshbooksError, 'FreshBooks access token not configured' if @access_token.blank?
      raise FreshbooksError, 'FreshBooks business ID not configured' if @business_id.blank?
    end

    private

    def headers
      {
        'Authorization' => "Bearer #{@access_token}",
        'Content-Type' => 'application/json',
        'Api-Version' => 'alpha'
      }
    end

    attr_reader :business_id

    def access_token_from_config
      # Try database first (for backward compatibility)
      token = FreshbooksToken.current
      return token.access_token if token&.access_token.present?

      # Then try environment/config
      ENV['FRESHBOOKS_ACCESS_TOKEN'] || Rails.application.config.freshbooks[:access_token]
    end

    def refresh_token_from_config
      token = FreshbooksToken.current
      return token.refresh_token if token&.refresh_token.present?

      ENV['FRESHBOOKS_REFRESH_TOKEN'] || Rails.application.config.freshbooks[:refresh_token]
    end

    def business_id_from_config
      token = FreshbooksToken.current
      return token.business_id if token&.business_id.present?

      ENV['FRESHBOOKS_BUSINESS_ID'] || Rails.application.config.freshbooks[:business_id]
    end

    def make_request(method, path, options = {})
      prepare_request(method, path, options)
      response = execute_request(method, path, options)

      case response.code
      when 200..299
        response.parsed_response
      when 401
        handle_401_response(method, path, options, response)
      else
        handle_other_error_response(response)
      end
    rescue HTTParty::Error => e
      raise FreshbooksError, "Network error: #{e.message}"
    end

    def prepare_request(method, path, options)
      options[:headers] = headers.merge(options[:headers] || {})
      Rails.logger.debug "FreshBooks API Request: #{method.upcase} #{path}"
      Rails.logger.debug "Business ID: #{business_id}"
      Rails.logger.debug "Headers: #{options[:headers].except('Authorization').inspect}"
    end

    def execute_request(method, path, options)
      self.class.send(method, path, options)
    end

    def handle_401_response(method, path, options, response)
      return handle_unauthorized_without_refresh_token(response) unless @refresh_token.present?

      refresh_and_retry(method, path, options)
    end

    def refresh_and_retry(method, path, options)
      Rails.logger.info 'FreshBooks API returned 401, attempting token refresh...'
      refresh_access_token
      Rails.logger.info 'Token refreshed successfully, retrying request...'

      rebuild_headers_with_new_token(options)
      response = execute_request(method, path, options)

      if response.success?
        response.parsed_response
      else
        handle_error_after_refresh(method, path, response)
      end
    end

    def rebuild_headers_with_new_token(options)
      existing_headers = (options[:headers] || {}).dup
      existing_headers.delete('Authorization')
      options[:headers] = headers.merge(existing_headers)
      token_preview = options[:headers]['Authorization']&.first(20)
      Rails.logger.debug "Retry with new token (first 20 chars): #{token_preview}..."
    end

    def handle_error_after_refresh(method, path, response)
      error_message = build_error_message("FreshBooks API error after token refresh: #{response.code}", response)
      Rails.logger.error "FreshBooks API request failed after refresh: #{error_message}"
      Rails.logger.error "Request: #{method.upcase} #{path}"
      Rails.logger.error "Response: #{response.body}"

      raise FreshbooksError.new(
        error_message,
        response.code,
        response.body
      )
    end

    def handle_unauthorized_without_refresh_token(response)
      error_message = build_error_message(
        'FreshBooks API error: Unauthorized (401). ' \
        'Token may be expired and no refresh token available.',
        response
      )

      raise FreshbooksError.new(
        error_message,
        response.code,
        response.body
      )
    end

    def handle_other_error_response(response)
      error_message = build_error_message("FreshBooks API error: #{response.code}", response)

      raise FreshbooksError.new(
        error_message,
        response.code,
        response.body
      )
    end

    def build_error_message(base_message, response)
      return base_message unless response.body.present?

      begin
        parsed = JSON.parse(response.body)
        error_detail = parsed['error_description'] || parsed['error'] || parsed['message'] || response.body
        "#{base_message} - #{error_detail}"
      rescue JSON::ParserError
        "#{base_message} - #{response.body}"
      end
    end

    def build_path(endpoint)
      "/accounting/account/#{business_id}/#{endpoint}"
    end
  end
end
