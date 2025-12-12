# frozen_string_literal: true

module WebflowWebhookHandling
  extend ActiveSupport::Concern

  private

  def process_webflow_item(webflow_item)
    webflow_item_hash = convert_item_to_hash(webflow_item)
    item_id = extract_item_id(webflow_item_hash)
    return { success: false, error: 'No item ID in item' } unless item_id.present?

    log_item_processing(item_id, webflow_item_hash)
    sync_item_to_rails(item_id, webflow_item_hash)
  rescue StandardError => e
    handle_item_processing_error(item_id, e)
  end

  def convert_item_to_hash(webflow_item)
    webflow_item.to_unsafe_h.deep_stringify_keys
  end

  def extract_item_id(webflow_item_hash)
    webflow_item_hash['id']
  end

  def log_item_processing(item_id, webflow_item_hash)
    Rails.logger.info "Webflow Webhook: Processing item #{item_id}"
    Rails.logger.info "Webflow Webhook: Item data keys: #{webflow_item_hash.keys.join(', ')}"
    Rails.logger.info "Webflow Webhook: fieldData keys: #{webflow_item_hash['fieldData']&.keys&.join(', ')}"
  end

  def sync_item_to_rails(item_id, webflow_item_hash)
    user = find_or_default_user(item_id)
    sync_service = Wrs::SyncService.new(admin_user: user)
    result = sync_service.call(webflow_item_hash)

    if result[:success]
      handle_successful_sync(item_id, result)
    else
      handle_failed_sync(item_id, result)
    end
  end

  def find_or_default_user(item_id)
    wrs = WindowScheduleRepair.find_by(webflow_item_id: item_id)
    wrs&.user || User.where(role: 'admin').first
  end

  def handle_successful_sync(item_id, result)
    Rails.logger.info "Webflow Webhook: Successfully synced WRS ##{result[:wrs_id]} from item #{item_id}"
    { success: true, wrs_id: result[:wrs_id], item_id: item_id }
  end

  def handle_failed_sync(item_id, result)
    Rails.logger.error "Webflow Webhook: Failed to sync item #{item_id} - #{result[:error]}"
    { success: false, error: result[:error], reason: result[:reason], item_id: item_id }
  end

  def handle_item_processing_error(item_id, error)
    Rails.logger.error "Webflow Webhook: Error processing item #{item_id}: #{error.message}"
    { success: false, error: error.message, item_id: item_id }
  end

  def verify_webflow_webhook?
    webhook_secret = ENV.fetch('WEBFLOW_WEBHOOK_SECRET', nil)
    return true if webhook_secret.blank?

    signature = extract_webflow_signature
    timestamp = extract_webflow_timestamp

    return false unless signature.present? && timestamp.present?
    return false unless validate_timestamp(timestamp)

    compare_webflow_signatures?(signature, timestamp, webhook_secret)
  end

  def extract_webflow_signature
    request.headers['X-Webflow-Signature'] || request.headers['HTTP_X_WEBFLOW_SIGNATURE']
  end

  def extract_webflow_timestamp
    request.headers['X-Webflow-Timestamp'] || request.headers['HTTP_X_WEBFLOW_TIMESTAMP']
  end

  def validate_timestamp(timestamp)
    request_time = timestamp.to_i
    current_time = (Time.now.to_f * 1000).to_i
    time_difference = (current_time - request_time).abs

    return false if time_difference > (5 * 60 * 1000) # 5 minutes in milliseconds

    true
  rescue StandardError => e
    Rails.logger.error "Webflow Webhook: Error validating timestamp: #{e.message}"
    false
  end

  def compare_webflow_signatures?(signature, timestamp, webhook_secret)
    expected_signature = compute_webflow_signature(timestamp, webhook_secret)

    if signature == expected_signature
      Rails.logger.info 'Webflow Webhook: Signature verified successfully'
      true
    else
      log_signature_mismatch(signature, expected_signature)
      false
    end
  end

  def compute_webflow_signature(timestamp, webhook_secret)
    body = request.raw_post
    signed_payload = "#{timestamp}:#{body}"
    OpenSSL::HMAC.hexdigest('SHA256', webhook_secret, signed_payload)
  end

  def log_signature_mismatch(received, expected)
    Rails.logger.warn 'Webflow Webhook: Invalid signature'
    Rails.logger.warn "  Received: #{received}"
    Rails.logger.warn "  Expected: #{expected}"
  end
end
