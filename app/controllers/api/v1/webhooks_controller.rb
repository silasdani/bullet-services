# frozen_string_literal: true

class Api::V1::WebhooksController < ActionController::API
  skip_before_action :verify_authenticity_token, raise: false

  # Webflow webhook for collection item published
  # Triggered when an item is published in Webflow
  def webflow_collection_item_published
    begin
      Rails.logger.info "Webflow Webhook Received: #{params.inspect}"

      unless verify_webflow_webhook?
        render json: { error: "Invalid webhook signature" }, status: :unauthorized
        return
      end

      # Extract the item data from the webhook payload
      # Webflow v2 published webhook sends items in an array
      payload = params[:payload]

      unless payload.present?
        Rails.logger.error "Webflow Webhook: No payload found in params: #{params.inspect}"
        render json: { error: "No payload provided in webhook" }, status: :bad_request
        return
      end

      # For published webhooks, the items are in an array
      items = payload[:items]
      unless items.present? && items.is_a?(Array) && items.any?
        Rails.logger.error "Webflow Webhook: No items found in payload: #{payload.inspect}"
        render json: { error: "No items in payload" }, status: :bad_request
        return
      end

      # Process each item (usually just one for published events)
      results = []
      items.each do |webflow_item|
        result = process_webflow_item(webflow_item)
        results << result
      end

      # Return response based on results
      if results.all? { |r| r[:success] }
        render json: {
          success: true,
          message: "All items synced successfully",
          results: results
        }, status: :ok
      else
        render json: {
          success: false,
          message: "Some items failed to sync",
          results: results
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

  def process_webflow_item(webflow_item)
    item_id = webflow_item[:id] || webflow_item["id"]
    unless item_id.present?
      Rails.logger.error "Webflow Webhook: No item ID found in item: #{webflow_item.inspect}"
      return { success: false, error: "No item ID in item" }
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
      { success: true, wrs_id: result[:wrs_id], item_id: item_id }
    else
      Rails.logger.error "Webflow Webhook: Failed to sync item #{item_id} - #{result[:error]}"
      { success: false, error: result[:error], reason: result[:reason], item_id: item_id }
    end
  rescue => e
    Rails.logger.error "Webflow Webhook: Error processing item #{item_id}: #{e.message}"
    { success: false, error: e.message, item_id: item_id }
  end

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
        return false
      end
    rescue => e
      Rails.logger.error "Webflow Webhook: Error validating timestamp: #{e.message}"
      return false
    end

    # Verify the signature matches
    body = request.raw_post
    signed_payload = "#{timestamp}:#{body}"
    expected_signature = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, signed_payload)

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

=begin
Webflow collection_item_published Webhook Payload Structure:

"triggerType" => "collection_item_published",
"payload" => {
  "items" => [
    {
      "id" => "68e6da253fab2e1905974866",
      "siteId" => "618ffc83f3028ad35a166db8",
      "workspaceId" => "686e45402f386a37da2a841b",
      "collectionId" => "619692f4b6773922b32797f2",
      "cmsLocaleId" => nil,
      "lastPublished" => "2025-10-08T22:00:36.371Z",
      "lastUpdated" => "2025-10-08T22:00:36.371Z",
      "createdOn" => "2025-10-08T21:39:49.725Z",
      "isArchived" => false,
      "isDraft" => false,
      "fieldData" => {
        "accepted-declined" => "#FFA500",
        "_noSearch" => false,
        "total-incl-vat" => 345.6,
        "total-exc-vat" => 288,
        "grand-total" => 345.6,
        "project-summary" => "1, one, 11",
        "flat-number" => "111",
        "name" => "1, one, 11 - 111",
        "window-location" => "1",
        "window-1-items-2" => "Easing and adjusting of sash window",
        "window-1-items-prices-3" => "300",
        "main-project-image" => {
          "fileId" => "68e6dae5abbb2d252189d889",
          "url" => "https://cdn.prod.website-files.com/.../image.jpeg",
          "alt" => nil
        },
        "slug" => "1-one-11-111-afcd"
      }
    }
  ]
}

Note: The published webhook sends items in an array, unlike the changed webhook
=end
