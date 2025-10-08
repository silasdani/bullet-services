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

      # Extract the item ID from the webhook payload
      # Webflow v2 sends payload in a nested structure
      item_id = params.dig(:payload, :id) || params[:_id] || params[:itemId] || params[:id]

      unless item_id.present?
        Rails.logger.error "Webflow Webhook: No item ID found in params: #{params.inspect}"
        render json: { error: "No item ID provided in webhook" }, status: :bad_request
        return
      end

      # Get the full item data from Webflow
      webflow_service = WebflowService.new
      webflow_item = webflow_service.get_item(item_id)

      # Find the WRS by webflow_item_id or create a new one
      wrs = WindowScheduleRepair.find_by(webflow_item_id: item_id)

      # Set the user (default to first admin if WRS doesn't exist)
      user = wrs&.user || User.where(role: "admin").first

      # Sync the item from Webflow to Rails
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
        }, status: :unprocessable_entity
      end

    rescue WebflowApiError => e
      Rails.logger.error "Webflow Webhook Error: #{e.message}"
      render json: {
        success: false,
        error: "Failed to fetch item from Webflow: #{e.message}"
      }, status: :unprocessable_entity
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

    # Get the signature from headers
    signature = request.headers["X-Webflow-Signature"]

    if signature.blank?
      Rails.logger.warn "Webflow Webhook: No X-Webflow-Signature header provided"
      Rails.logger.warn "Available headers: #{request.headers.to_h.select { |k, _| k.start_with?('HTTP_') }.keys.join(', ')}"
      return false
    end

    # Verify the signature matches
    # Webflow uses HMAC-SHA256 for webhook signatures
    body = request.raw_post
    expected_signature = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, body)

    Rails.logger.debug "Webflow Webhook Signature Verification:"
    Rails.logger.debug "  Received signature: #{signature}"
    Rails.logger.debug "  Expected signature: #{expected_signature}"
    Rails.logger.debug "  Body length: #{body.length}"

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
