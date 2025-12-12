# frozen_string_literal: true

module FreshbooksWebhookVerification
  extend ActiveSupport::Concern

  private

  def handle_verification
    callback_id = extract_callback_id
    verification_code = extract_verification_code

    log_verification_request(callback_id, verification_code)

    if verification_code.present? && callback_id.present?
      verify_webhook_via_api(callback_id, verification_code)
    else
      acknowledge_verification_request
    end
  end

  def extract_callback_id
    params[:callback_id] || params[:id]
  end

  def extract_verification_code
    params[:verifier] || params[:verification_code]
  end

  def log_verification_request(callback_id, verification_code)
    Rails.logger.info 'FreshBooks webhook verification request received'
    Rails.logger.info "  Callback ID: #{callback_id}"
    Rails.logger.info "  Verification code: #{verification_code.present? ? 'present' : 'missing'}"
    Rails.logger.info "  All params: #{params.inspect}"
  end

  def verify_webhook_via_api(callback_id, verification_code)
    webhooks = Freshbooks::Webhooks.new
    result = webhooks.verify(callback_id, verification_code)

    if result&.dig('verified')
      handle_successful_verification(callback_id)
    else
      handle_unverified_status(callback_id)
    end
  rescue FreshbooksError => e
    handle_verification_error(callback_id, e)
  end

  def handle_successful_verification(callback_id)
    Rails.logger.info "✅ Webhook #{callback_id} verified successfully"
    render json: { status: 'verified', callback_id: callback_id }, status: :ok
  end

  def handle_unverified_status(callback_id)
    Rails.logger.warn '⚠️  Webhook verification returned but status is unverified'
    render json: { status: 'pending', callback_id: callback_id }, status: :ok
  end

  def handle_verification_error(_callback_id, error)
    Rails.logger.error "❌ Failed to verify webhook: #{error.message}"
    Rails.logger.error "Response: #{error.response_body}" if error.respond_to?(:response_body)
    render json: { status: 'verification_failed', error: error.message }, status: :ok
  end

  def acknowledge_verification_request
    Rails.logger.info 'Verification request received (missing callback_id or verification_code)'
    render json: { status: 'received' }, status: :ok
  end

  def verify_webhook_signature
    return true if skip_signature_verification?

    webhook_secret = Rails.application.config.freshbooks[:webhook_secret]
    return true if webhook_secret.blank?

    signature = extract_signature
    return false if signature.blank?

    compare_signatures(signature, webhook_secret)
  end

  def skip_signature_verification?
    params[:verification_code].present? || params[:verifier].present?
  end

  def extract_signature
    request.headers['X-FreshBooks-Hmac-SHA256']
  end

  def compare_signatures(signature, webhook_secret)
    expected_signature = compute_expected_signature(webhook_secret)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end

  def compute_expected_signature(webhook_secret)
    data = request.form_data? ? request.form_data.to_json : request.raw_post
    Base64.strict_encode64(
      OpenSSL::HMAC.digest('sha256', webhook_secret, data)
    )
  end
end
