# frozen_string_literal: true

# OAuth callback controller that automatically exchanges authorization code for tokens
class FreshbooksCallbackController < ApplicationController
  skip_before_action :verify_authenticity_token

  def callback
    code = params[:code]
    error = params[:error]

    if error.present?
      render html: error_page("OAuth Error: #{error}"), status: :bad_request
      return
    end

    if code.blank?
      render html: error_page('No authorization code received. Please try again.'), status: :bad_request
      return
    end

    begin
      result = Freshbooks::OauthService.exchange_code(code)
      render html: success_page(result)
    rescue FreshbooksError => e
      render html: error_page("Failed to exchange authorization code: #{e.message}"), status: :bad_request
    rescue StandardError => e
      Rails.logger.error "FreshBooks OAuth error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render html: error_page("An unexpected error occurred: #{e.message}"), status: :internal_server_error
    end
  end

  private

  def success_page(result)
    expires_hours = (result[:expires_in] / 3600.0).round(2)
    <<~HTML
      <html>
        <head>
          <title>FreshBooks OAuth Success</title>
          <meta http-equiv="refresh" content="5;url=/">
        </head>
        <body style="font-family: Arial; padding: 40px; max-width: 600px; margin: 0 auto;">
          <h1 style="color: #28a745;">✅ Authorization Successful!</h1>
          <p>Your FreshBooks account has been successfully connected.</p>
          <p><strong>Business ID:</strong> #{result[:business_id]}</p>
          <p><strong>Token expires in:</strong> #{expires_hours} hours</p>
          <p style="color: #6c757d; font-size: 14px;">Tokens have been automatically saved to the database.</p>
          <p style="color: #6c757d; font-size: 14px; margin-top: 20px;">Redirecting in 5 seconds...</p>
        </body>
      </html>
    HTML
  end

  def error_page(message)
    <<~HTML
      <html>
        <head><title>FreshBooks OAuth Error</title></head>
        <body style="font-family: Arial; padding: 40px; max-width: 600px; margin: 0 auto;">
          <h1 style="color: #dc3545;">❌ Authorization Failed</h1>
          <p>#{message}</p>
          <p><strong>Common issues:</strong></p>
          <ul>
            <li>Authorization code expired (codes expire in ~10 minutes)</li>
            <li>Code already used</li>
            <li>Redirect URI mismatch</li>
            <li>Invalid client credentials</li>
          </ul>
          <p><a href="/">Return to home</a></p>
        </body>
      </html>
    HTML
  end
end
