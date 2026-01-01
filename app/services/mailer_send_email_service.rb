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

    with_error_handling do
      @mailersend_token = ENV.fetch('MAILERSEND_API_TOKEN', nil)
      return add_error('MailerSend API token is not configured') if @mailersend_token.blank?

      email = build_email
      response = email.send
      handle_response(response)
    end
  rescue StandardError => e
    handle_exception(e)
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
    Mailersend::Email.new(api_token: @mailersend_token)
  rescue ArgumentError
    Mailersend::Email.new
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
    # Handle Hash response (common with some MailerSend versions)
    if response.is_a?(Hash)
      handle_hash_response(response)
    elsif response.respond_to?(:status) && response.status.respond_to?(:success?) && !response.status.success?
      handle_error_response(response)
    else
      log_info("MailerSend email queued to #{to} (template_id=#{template_id || 'none'}), response=#{response.inspect}")
      @result = { success: true, response: response }
      self
    end
  end

  def handle_hash_response(response)
    # Check if it's an error response
    if response['status_code'].present? && response['status_code'] >= 400
      status_code = response['status_code']
      body_text = response['body'] || response['message'] || response.inspect
      log_error("MailerSend HTTP #{status_code}: #{body_text}")
      add_error("MailerSend HTTP #{status_code}: #{body_text}")
      @result = { success: false, response: response }
    else
      log_info("MailerSend email queued to #{to} (template_id=#{template_id || 'none'}), response=#{response.inspect}")
      @result = { success: true, response: response }
    end
    self
  end

  def handle_error_response(response)
    status_code = extract_status_code(response)
    body_text = extract_body_text(response)

    log_error("MailerSend HTTP #{status_code}: #{body_text}")
    add_error("MailerSend HTTP #{status_code}: #{body_text}")
    @result = { success: false, response: response }
    self
  end

  def extract_status_code(response)
    if response.respond_to?(:status)
      status = response.status
      if status.respond_to?(:code)
        status.code
      elsif status.is_a?(Numeric)
        status
      else
        status.to_s
      end
    elsif response.is_a?(Hash)
      response['status_code'] || response[:status_code] || response['status'] || response[:status] || 'unknown'
    else
      'unknown'
    end
  end

  def extract_body_text(response)
    if response.respond_to?(:body) && response.body.respond_to?(:to_s)
      response.body.to_s
    elsif response.is_a?(Hash)
      response['body'] || response[:body] || response['message'] || response[:message] || response.inspect
    else
      response.inspect
    end
  end

  def handle_exception(error)
    error_message = "MailerSend error: #{error.message}"
    log_error(error_message)
    add_error(error_message)
    self
  end
end
