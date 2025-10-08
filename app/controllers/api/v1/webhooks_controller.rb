# frozen_string_literal: true

class Api::V1::WebhooksController < ActionController::API
  # Skip authentication for webhooks
  skip_before_action :verify_authenticity_token, raise: false

  # Webflow webhook for collection item changes
  # Triggered when an item is created, updated, or deleted in Webflow
  def webflow_collection_item_changed
    begin
      # Log the webhook for debugging
      Rails.logger.info "Webflow Webhook Received: #{params.inspect}"
      Rails.logger.info "Webflow Webhook Headers: #{request.headers.to_h.select { |k, _| k.start_with?('HTTP_') || k == 'X-Webflow-Signature' }.inspect}"

      # Verify webhook signature if available
      unless verify_webflow_webhook?
        render json: { error: "Invalid webhook signature" }, status: :unauthorized
        return
      end

      # Extract the item data from the webhook payload
      # Webflow v2 sends the complete item data in the payload, so we don't need to fetch it from the API
      webflow_item = params[:payload]

      unless webflow_item.present?
        Rails.logger.error "Webflow Webhook: No payload found in params: #{params.inspect}"
        render json: { error: "No payload provided in webhook" }, status: :bad_request
        return
      end

      item_id = webflow_item[:id]
      unless item_id.present?
        Rails.logger.error "Webflow Webhook: No item ID found in payload: #{webflow_item.inspect}"
        render json: { error: "No item ID in payload" }, status: :bad_request
        return
      end

      Rails.logger.info "Webflow Webhook: Processing item #{item_id}"

      # Find the WRS by webflow_item_id or create a new one
      wrs = WindowScheduleRepair.find_by(webflow_item_id: item_id)

      # Set the user (default to first admin if WRS doesn't exist)
      user = wrs&.user || User.where(role: "admin").first

      # Sync the item from Webflow to Rails using the webhook payload data
      # Note: WrsSyncService automatically sets skip_webflow_sync=true to prevent circular loops
      sync_service = WrsSyncService.new(user)
      result = sync_service.sync_single(webflow_item)

      if result[:success]
        Rails.logger.info "Webflow Webhook: Successfully synced WRS ##{result[:wrs_id]} from item #{item_id}"
        render json: {
          success: true,
          message: "WRS synced successfully",
          wrs_id: result[:wrs_id]
        }, status: :ok
      else
        Rails.logger.error "Webflow Webhook: Failed to sync item #{item_id} - #{result[:error]}"
        render json: {
          success: false,
          error: result[:error],
          reason: result[:reason]
        }, status: :unprocessable_content
      end

    rescue WebflowApiError => e
      Rails.logger.error "Webflow Webhook Error: #{e.message}"
      render json: {
        success: false,
        error: "Webflow API error: #{e.message}"
      }, status: :unprocessable_content
    rescue => e
      Rails.logger.error "Webflow Webhook Unexpected Error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      render json: {
        success: false,
        error: "Unexpected error: #{e.message}"
      }, status: :internal_server_error
    end
  end

  private

  def verify_webflow_webhook?
    # Webflow sends a signature header for webhook verification
    # If you have a webhook secret configured, verify it here
    webhook_secret = ENV["WEBFLOW_WEBHOOK_SECRET"]

    # If no secret is configured, allow all requests (less secure)
    if webhook_secret.blank?
      Rails.logger.info "Webflow Webhook: No WEBFLOW_WEBHOOK_SECRET configured, skipping signature verification"
      return true
    end

    # Get the signature and timestamp from headers
    # Rails converts HTTP headers to HTTP_* format, so X-Webflow-Signature becomes HTTP_X_WEBFLOW_SIGNATURE
    signature = request.headers["X-Webflow-Signature"] || request.headers["HTTP_X_WEBFLOW_SIGNATURE"]
    timestamp = request.headers["X-Webflow-Timestamp"] || request.headers["HTTP_X_WEBFLOW_TIMESTAMP"]

    if signature.blank?
      Rails.logger.warn "Webflow Webhook: No X-Webflow-Signature header provided"
      Rails.logger.warn "Available headers: #{request.headers.to_h.select { |k, _| k.start_with?('HTTP_') }.keys.join(', ')}"
      return false
    end

    if timestamp.blank?
      Rails.logger.warn "Webflow Webhook: No X-Webflow-Timestamp header provided"
      return false
    end

    # Validate timestamp to prevent replay attacks (timestamp should be within 5 minutes)
    begin
      request_time = timestamp.to_i
      current_time = (Time.now.to_f * 1000).to_i  # Convert to milliseconds
      time_difference = (current_time - request_time).abs

      if time_difference > (5 * 60 * 1000)  # 5 minutes in milliseconds
        Rails.logger.warn "Webflow Webhook: Timestamp too old (difference: #{time_difference}ms)"
        Rails.logger.warn "  Request time: #{request_time}, Current time: #{current_time}"
        return false
      end
    rescue => e
      Rails.logger.error "Webflow Webhook: Error validating timestamp: #{e.message}"
      return false
    end

    # Verify the signature matches
    # Webflow uses HMAC-SHA256 for webhook signatures
    # The signature is computed as: HMAC-SHA256(timestamp + ":" + body, secret)
    body = request.raw_post
    signed_payload = "#{timestamp}:#{body}"
    expected_signature = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, signed_payload)

    Rails.logger.debug "Webflow Webhook Signature Verification:"
    Rails.logger.debug "  Received signature: #{signature}"
    Rails.logger.debug "  Expected signature: #{expected_signature}"
    Rails.logger.debug "  Timestamp: #{timestamp}"
    Rails.logger.debug "  Body length: #{body.length}"
    Rails.logger.debug "  Body first 200 chars: #{body[0...200]}"
    Rails.logger.debug "  Signed payload first 200 chars: #{signed_payload[0...200]}"
    Rails.logger.debug "  Webhook secret length: #{webhook_secret.length}"
    Rails.logger.debug "  Webhook secret first 10 chars: #{webhook_secret[0...10]}"

    if signature == expected_signature
      Rails.logger.info "Webflow Webhook: Signature verified successfully"
      true
    else
      Rails.logger.warn "Webflow Webhook: Invalid signature"
      Rails.logger.warn "  Received: #{signature}"
      Rails.logger.warn "  Expected: #{expected_signature}"
      false
    end
  end
end
