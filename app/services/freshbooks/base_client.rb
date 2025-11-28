# frozen_string_literal: true

module Freshbooks
  class BaseClient
    include HTTParty

    base_uri Rails.application.config.freshbooks[:api_base_url]

    def initialize(access_token: nil, refresh_token: nil, business_id: nil)
      @access_token = access_token || get_access_token_from_config
      @refresh_token = refresh_token || get_refresh_token_from_config
      @business_id = business_id || get_business_id_from_config

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

    def get_access_token_from_config
      # Try database first (for backward compatibility)
      token = FreshbooksToken.current
      return token.access_token if token&.access_token.present?

      # Then try environment/config
      ENV['FRESHBOOKS_ACCESS_TOKEN'] || Rails.application.config.freshbooks[:access_token]
    end

    def get_refresh_token_from_config
      token = FreshbooksToken.current
      return token.refresh_token if token&.refresh_token.present?

      ENV['FRESHBOOKS_REFRESH_TOKEN'] || Rails.application.config.freshbooks[:refresh_token]
    end

    def get_business_id_from_config
      token = FreshbooksToken.current
      return token.business_id if token&.business_id.present?

      ENV['FRESHBOOKS_BUSINESS_ID'] || Rails.application.config.freshbooks[:business_id]
    end

    def refresh_token_if_needed
      return unless @refresh_token.present?

      # Check if token is expired (if we have expiry info)
      token = FreshbooksToken.current
      return unless token&.expires_soon?

      refresh_access_token
    end

    def refresh_access_token
      config = Rails.application.config.freshbooks
      response = HTTParty.post(
        "#{config[:auth_base_url]}/oauth/token",
        body: {
          grant_type: 'refresh_token',
          refresh_token: @refresh_token,
          client_id: config[:client_id],
          client_secret: config[:client_secret]
        },
        headers: { 'Content-Type' => 'application/json' }
      )

      if response.success?
        data = response.parsed_response
        @access_token = data['access_token']
        @refresh_token = data['refresh_token'] || @refresh_token

        # Update database token if it exists
        token = FreshbooksToken.current
        if token
          expires_at = Time.current + data['expires_in'].seconds
          token.update!(
            access_token: @access_token,
            refresh_token: @refresh_token,
            token_expires_at: expires_at
          )
        end
      else
        raise FreshbooksError.new(
          'Failed to refresh access token',
          response.code,
          response.body
        )
      end
    end

    def make_request(method, path, options = {})
      options[:headers] = headers.merge(options[:headers] || {})

      response = self.class.send(method, path, options)

      case response.code
      when 200..299
        response.parsed_response
      when 401
        # Token might be expired, try refreshing once if we have refresh token
        if @refresh_token.present?
          refresh_access_token
          options[:headers] = headers.merge(options[:headers] || {})
          response = self.class.send(method, path, options)
          if response.success?
            response.parsed_response
          else
            raise FreshbooksError.new(
              "FreshBooks API error: #{response.code}",
              response.code,
              response.body
            )
          end
        else
          raise FreshbooksError.new(
            'FreshBooks API error: Unauthorized (401). Token may be expired and no refresh token available.',
            response.code,
            response.body
          )
        end
      else
        raise FreshbooksError.new(
          "FreshBooks API error: #{response.code}",
          response.code,
          response.body
        )
      end
    rescue HTTParty::Error => e
      raise FreshbooksError, "Network error: #{e.message}"
    end

    def build_path(endpoint)
      "/accounting/account/#{business_id}/#{endpoint}"
    end
  end
end
