# frozen_string_literal: true

class MailerSendEmailService < ApplicationService
  # Simple wrapper around the MailerSend Ruby SDK for transactional emails.
  #
  # Supports:
  # - direct subject/body sends
  # - template-based sends (you configure templates in MailerSend UI)
  #
  # Usage – simple content:
  #   MailerSendEmailService.new(
  #     to: user.email,
  #     subject: "Welcome",
  #     text: "Hello",
  #     html: "<p>Hello</p>"
  #   ).call
  #
  # Usage – template:
  #   MailerSendEmailService.new(
  #     to: user.email,
  #     template_id: "your-template-id",
  #     variables: { "name" => user.name }
  #   ).call

  attr_accessor :to, :subject, :text, :html, :from_email, :from_name, :template_id, :variables

  def initialize(to:, **options)
    super()
    @to         = to
    @subject    = options[:subject]
    @text       = options[:text]
    @html       = options[:html]
    @from_email = options[:from_email] || ENV.fetch('MAILERSEND_FROM_EMAIL', 'no-reply@example.com')
    @from_name  = options[:from_name] || ENV.fetch('MAILERSEND_FROM_NAME', 'Bullet Services')
    @template_id = options[:template_id]
    @variables   = options[:variables] || {}
  end

  def call
    return self unless valid_request?

    @mailersend_token = ENV.fetch('MAILERSEND_API_TOKEN', nil)
    return add_error('MailerSend API token is not configured') if @mailersend_token.blank?

    begin
      email = build_email
      response = email.send
      handle_response(response)
    rescue StandardError => e
      log_error("MailerSend email failed: #{e.class}: #{e.message}")
      add_error("Failed to send email: #{e.message}")
      @result = { success: false, error: e.message }
      self
    end
  end

  private

  def valid_request?
    if to.blank?
      add_error('Recipient email is required')
      return false
    end

    if template_id.blank? && subject.blank?
      add_error('Either template_id or (subject and content) is required')
      return false
    end

    if template_id.blank? && text.blank? && html.blank?
      add_error('Either text or html content is required when not using a template')
      return false
    end

    true
  end

  def build_email
    with_token_env do
      email = initialize_email_client
      configure_email_recipients(email)
      apply_email_content(email)
      email
    end
  end

  def with_token_env
    original_token = ENV.fetch('MAILERSEND_API_TOKEN', nil)
    ENV['MAILERSEND_API_TOKEN'] = @mailersend_token
    yield
  ensure
    restore_env_token(original_token)
  end

  def initialize_email_client
    # Mailersend::Email.new expects a Client object, not api_token keyword
    # Create the client with the token, then pass it to Email
    client = Mailersend::Client.new(@mailersend_token)
    Mailersend::Email.new(client)
  end

  def configure_email_recipients(email)
    email.add_recipients('email' => to)
    email.add_from('email' => from_email, 'name' => from_name)
  end

  def apply_email_content(email)
    if template_id.present?
      apply_template_content(email)
    else
      apply_direct_content(email)
    end
  end

  def restore_env_token(original_token)
    if original_token.nil?
      ENV.delete('MAILERSEND_API_TOKEN')
    else
      ENV['MAILERSEND_API_TOKEN'] = original_token
    end
  end

  def apply_template_content(email)
    # Some MailerSend templates still require a subject in the API call.
    email.add_subject(subject) if subject.present?
    email.template_id = template_id

    # MailerSend expects variables as array of hashes:
    # [{ "email" => to, "substitutions" => [{ "var" => "name", "value" => "John" }, ...] }]
    return if variables.blank?

    substitutions = variables.map { |key, value| { 'var' => key.to_s, 'value' => value } }
    email.variables = [
      {
        'email' => to,
        'substitutions' => substitutions
      }
    ]
  end

  def apply_direct_content(email)
    email.add_subject(subject)
    email.add_text(text) if text.present?
    email.add_html(html) if html.present?
  end

  def handle_response(response)
    log_debug("MailerSend response type: #{response.class}")

    if http_response?(response)
      handle_http_response(response)
    elsif response.is_a?(Hash)
      handle_hash_response(response)
    else
      handle_default_response(response)
    end
  end

  def http_response?(response)
    response.respond_to?(:status) && response.status.respond_to?(:code)
  end

  def handle_http_response(response)
    status_code = response.status.code

    if success_status?(status_code)
      handle_http_success(response, status_code)
    else
      handle_http_error(response, status_code)
    end

    self
  end

  def success_status?(status_code)
    status_code >= 200 && status_code < 300
  end

  def handle_http_success(response, status_code)
    message_id = extract_message_id(response)
    log_message = build_success_log_message(status_code, message_id)
    log_info(log_message)
    @result = { success: true, response: response, status_code: status_code, message_id: message_id }
  end

  def extract_message_id(response)
    response.headers['x-message-id'] if response.respond_to?(:headers)
  end

  def build_success_log_message(status_code, message_id)
    log_message = "MailerSend email queued to #{to} (template_id=#{template_id || 'none'}, status=#{status_code}"
    log_message += ", message_id=#{message_id}" if message_id
    "#{log_message})"
  end

  def handle_http_error(response, status_code)
    body_text = response_body_text(response)
    log_error("MailerSend HTTP #{status_code}: #{body_text}")
    add_error("MailerSend HTTP #{status_code}: #{body_text}")
    @result = { success: false, response: response, status_code: status_code }
  end

  def handle_hash_response(response)
    status_code = response['status_code'] || response[:status_code]

    if error_status?(status_code)
      handle_hash_error(response, status_code)
    else
      handle_hash_success(response)
    end

    self
  end

  def error_status?(status_code)
    status_code.is_a?(Numeric) && status_code >= 400
  end

  def handle_hash_error(response, status_code)
    body_text = response['body'] || response['message'] || 'Unknown error'
    log_error("MailerSend HTTP #{status_code}: #{body_text}")
    add_error("MailerSend HTTP #{status_code}: #{body_text}")
    @result = { success: false, response: response }
  end

  def handle_hash_success(response)
    log_info("MailerSend email queued to #{to}")
    @result = { success: true, response: response }
  end

  def handle_default_response(response)
    log_info("MailerSend email queued to #{to} (template_id=#{template_id || 'none'})")
    @result = { success: true, response: response }
    self
  end

  def response_body_text(response)
    if response.respond_to?(:body)
      body = response.body
      body.respond_to?(:to_s) ? body.to_s : body.inspect
    else
      response.inspect
    end
  end
end
