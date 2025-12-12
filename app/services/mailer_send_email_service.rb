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
      return add_error('MailerSend API token is not configured') if MAILERSEND_API_TOKEN.blank?

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
    # The MailerSend Ruby SDK reads the API token from ENV['MAILERSEND_API_TOKEN']
    email = Mailersend::Email.new

    email.add_recipients('email' => to)
    email.add_from('email' => from_email, 'name' => from_name)

    if template_id.present?
      apply_template_content(email)
    else
      apply_direct_content(email)
    end

    email
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
    if response.respond_to?(:status) && !response.status.success?
      handle_error_response(response)
    else
      log_info("MailerSend email queued to #{to} (template_id=#{template_id || 'none'}), response=#{response.inspect}")
      @result = { success: true, response: response }
      self
    end
  end

  def handle_error_response(response)
    body_text =
      if response.respond_to?(:body) && response.body.respond_to?(:to_s)
        response.body.to_s
      else
        response.inspect
      end

    log_error("MailerSend HTTP #{response.status}: #{body_text}")
    add_error("MailerSend HTTP #{response.status}: #{body_text}")
    @result = { success: false, response: response }
    self
  end

  def handle_exception(error)
    error_message = "MailerSend error: #{error.message}"
    log_error(error_message)
    add_error(error_message)
    self
  end
end
